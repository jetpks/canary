require "async"
require "async/semaphore"
require "tempfile"

module Canary
  module Eval
    # corpus x model x k -> Canary::Eval::Record, one per sample. Per sample:
    # render (hidden by default) -> sample via Canary::Sampler -> extract via
    # Canary::Extractor -> materialize the extracted code as a scratch file
    # -> verify via Canary::Verifier -> one record.
    #
    # Fans the jobs out under a bounded Async::Semaphore (BRIEF §4.1: fibers,
    # never threads), one job (task, model, sample_index) at a time -
    # Sampler#call itself stays a sequential Array.new(n), so the
    # concurrency across samples lives here, not there.
    class Runner
      SCHEMA_VERSION = 1

      # Deliberately low. Each concurrent job holds one in-flight provider
      # call against a rate-limited API, and every job whose response
      # extracts cleanly then forks two OS processes for the rollout
      # (Pool#fork_and_collect's relay + worker, pool.rb:109-142) - an
      # unbounded fan-out multiplies both at once. 5 keeps at most ~10 live
      # child processes on the machine at any moment while still giving real
      # wall-clock benefit over running 91 calls strictly sequentially.
      DEFAULT_CONCURRENCY = 5

      Job = Data.define(:entry, :model, :index, :grader) do
        def render_mode
          grader ? :grader_visible : :hidden
        end
      end
      private_constant :Job

      def initialize(sampler:, verifier: Verifier.new, concurrency: DEFAULT_CONCURRENCY)
        @sampler = sampler
        @verifier = verifier
        @concurrency = concurrency
      end

      # +entries+ is an Array of Canary::TaskRepo::Entry, +models+ an Array
      # of model name strings. Returns one Record per (entry, model, k)
      # combination - order is not significant, Report groups by task_name.
      #
      # A block, if given, is called with each Record as soon as its job
      # completes - before the run as a whole returns - so a caller can
      # persist records as they land instead of losing everything already
      # paid for when a later job raises (I15 F2). A job that raises is not
      # caught here: it propagates out of Sync and aborts the run, and does
      # not itself yield a Record - it is a harness crash, not a model
      # non-score, and the two must not be reported the same way.
      def call(entries:, models:, k:, grader: false, &on_record)
        jobs = entries.product(models).flat_map { |entry, model| Array.new(k) { |index| Job.new(entry, model, index, grader) } }

        Sync do
          semaphore = Async::Semaphore.new(@concurrency)
          jobs.map { |job| semaphore.async { run_one(job).tap { |record| on_record&.call(record) } } }.map(&:wait)
        end
      end

      private

      def run_one(job)
        result = @sampler.call(job.entry, model: job.model, n: 1, base_index: job.index, grader: job.grader).first

        return provider_failure_record(job, result.failure) if result.failure? && !result.failure.text

        sample = result.success? ? result.success : sample_from_failure(result.failure)
        extracted = Extractor.call(sample.text)

        return extractor_refusal_record(job, sample, extracted) unless extracted.outcome == :ok

        verified_record(job, sample, extracted)
      end

      # A text-less provider Failure never reached the extractor or the
      # verifier - the reasons here (:refusal, :truncated from the content
      # outcomes with no recoverable text; :transport_error,
      # :budget_exhausted, :spend_exceeded from the guards Sampler checks
      # pre-flight) are all "the pipeline never produced gradable code," the
      # same class of non-score R3 names explicitly. A Failure whose
      # error.text IS present skips this and goes through sample_from_failure
      # instead - see run_one.
      def provider_failure_record(job, error)
        Record.new(**identity_fields(job),
          scored: false,
          non_score_reason: error.reason,
          passed: nil,
          stop_reason: error.raw&.dig(:stop_reason),
          input_tokens: error.raw&.dig(:usage, :input_tokens),
          output_tokens: error.raw&.dig(:usage, :output_tokens))
      end

      # Wraps a text-carrying Failure's error in the same shape a Success
      # hands the rest of run_one, so a truncated-or-refused-but-still-
      # readable response gets the identical extract -> prefilter -> grade
      # path a Success takes (AC7) rather than a second, parallel one.
      # stop_reason is read off raw the same honest way
      # provider_failure_record already does above - never :end_turn/:stop,
      # so the truncation or refusal stays visible on a record this yields
      # even when that record ends up scored: true. The provider's own
      # monad arm never changes: this only reshapes data already returned
      # as a Failure, it never becomes a Success.
      def sample_from_failure(error)
        Providers::Sample.new(text: error.text, raw: error.raw, stop_reason: error.raw&.dig(:stop_reason))
      end

      # The model answered, but the extractor found nothing gradable - no
      # Ruby fence at all, or a fence tagged for another language. Collapsed
      # to the one frozen reason (:extractor_refusal); the specific shape
      # (:no_fenced_code vs :no_ruby_fence) still lives in extractor_outcome.
      def extractor_refusal_record(job, sample, extracted)
        Record.new(**identity_fields(job),
          scored: false,
          non_score_reason: :extractor_refusal,
          passed: nil,
          extractor_outcome: extracted.outcome,
          stop_reason: sample.stop_reason,
          input_tokens: sample.raw.dig(:usage, :input_tokens),
          output_tokens: sample.raw.dig(:usage, :output_tokens))
      end

      # Cutoff stop reasons a provider evidences when it ran out of budget
      # mid-generation: Anthropic reports :max_tokens (providers/anthropic.rb),
      # OpenAICompat normalizes finish_reason "length" to :length
      # (providers/openai_compat.rb). Only these two make an EOF-anchored
      # prefilter truncation an honest :truncated - see non_score_reason_for.
      CUTOFF_STOP_REASONS = %i[max_tokens length].freeze

      # A genuine verdict: the extracted code got a real shot at the
      # verifier, whatever it did there. A prefilter reject is scored:
      # true, passed: false - the model's own code falling short - UNLESS
      # the prefilter rejected it because the generation ends mid-construct
      # (Prefilter::Report#truncated), which is a non-score (R3) rather than
      # a graded failure. That EOF-anchored parse error is truncation only
      # when the provider itself evidenced a cutoff (see
      # non_score_reason_for) - a clean stop_reason means the model finished
      # on its own and simply wrote code that doesn't parse, so the record
      # names that distinctly rather than blaming the harness for it.
      def verified_record(job, sample, extracted)
        Tempfile.create(["canary_eval_", ".rb"]) do |file|
          file.write(extracted.code)
          file.flush

          task = Task.new(solution_path: file.path, test_path: job.entry.reference.test_path, adapter: job.entry.adapter)
          result = @verifier.call(task)

          next non_score_record(job, sample, extracted, non_score_reason_for(sample)) if result.prefilter_report.truncated

          Record.new(**identity_fields(job),
            scored: true,
            non_score_reason: nil,
            passed: result.passed,
            prefilter_clean: result.prefilter_report.clean?,
            rollout_outcome: result.rollout_result&.outcome,
            passed_examples: result.rollout_result&.passed,
            total_examples: result.rollout_result&.total,
            coverage_fraction: coverage_fraction(result.rollout_result, file.path),
            extractor_outcome: extracted.outcome,
            stop_reason: sample.stop_reason,
            input_tokens: sample.raw.dig(:usage, :input_tokens),
            output_tokens: sample.raw.dig(:usage, :output_tokens))
        end
      end

      # :truncated only when the sample's own stop_reason evidences a
      # provider-side cutoff (CUTOFF_STOP_REASONS); any other stop_reason
      # means the model stopped generating on its own and the EOF-anchored
      # parse error is its own doing, named :premature_stop rather than
      # folded into a harness limitation it isn't.
      def non_score_reason_for(sample)
        CUTOFF_STOP_REASONS.include?(sample.stop_reason) ? :truncated : :premature_stop
      end

      def non_score_record(job, sample, extracted, reason)
        Record.new(**identity_fields(job),
          scored: false,
          non_score_reason: reason,
          passed: nil,
          prefilter_clean: false,
          extractor_outcome: extracted.outcome,
          stop_reason: sample.stop_reason,
          input_tokens: sample.raw.dig(:usage, :input_tokens),
          output_tokens: sample.raw.dig(:usage, :output_tokens))
      end

      def identity_fields(job)
        {
          schema_version: SCHEMA_VERSION,
          task_name: job.entry.name,
          model: job.model,
          sample_index: job.index,
          render_mode: job.render_mode
        }
      end

      def coverage_fraction(rollout_result, solution_path)
        lines = rollout_result&.coverage&.dig(solution_path, :lines)&.compact
        return nil if lines.nil? || lines.empty?

        lines.count(&:positive?) / lines.size.to_f
      end
    end
  end
end
