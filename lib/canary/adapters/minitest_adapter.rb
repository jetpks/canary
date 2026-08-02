require "minitest"

module Canary
  module Adapters
    # Drives Minitest::Runnable directly rather than Minitest.run, since the
    # latter is designed around a single process-lifetime CLI invocation
    # (at_exit hooks, autorun). We fork-and-die per rollout instead, so we
    # only need the pieces that run a suite and hand back results.
    class MinitestAdapter
      NAME = :minitest

      # Preloads Minitest itself. Called once in the parent, before
      # Coverage.start, so none of this file's parsing is instrumented.
      #
      # "pp" is preloaded too: Minitest::Test.make_my_diffs_pretty! (a real,
      # if rare, submission-facing API) lazily requires it, and a submission
      # that calls it would otherwise leak pp/prettyprint into its own
      # coverage.
      def self.preload
        require "minitest"
        require "pp"
        self
      end

      # Loads +submission_path+ (which must happen after Coverage.start in
      # the caller) and runs every Minitest::Test subclass it newly defines.
      def run(submission_path)
        before = Minitest::Runnable.runnables.dup
        load submission_path
        klasses = Minitest::Runnable.runnables - before

        Minitest.seed = 42
        reporter = CollectingReporter.new

        klasses.each do |klass|
          klass.run_suite(reporter, {}) if klass.respond_to?(:run_suite)
        end

        examples = reporter.results.map do |result|
          status = if result.skipped?
                     :skipped
                   elsif result.passed?
                     :passed
                   else
                     :failed
                   end

          ExampleResult.new(
            name: "#{result.klass}##{result.name}",
            status: status,
            message: result.passed? ? nil : result.failure&.message
          )
        end

        passed = examples.count { |e| e.status == :passed }
        failed = examples.count { |e| e.status == :failed }

        RolloutResult.new(
          adapter: NAME,
          examples: examples,
          passed: passed,
          failed: failed,
          total: examples.size
        )
      end

      # Records every result, not just failures, so the pool can report a
      # full pass/fail breakdown.
      class CollectingReporter < Minitest::AbstractReporter
        attr_reader :results

        def initialize
          super
          @results = []
        end

        def record(result)
          @results << Minitest::Result.from(result)
        end
      end
    end
  end
end
