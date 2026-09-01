require "test_helper"
require "async"
require "tempfile"
require "json"

# Proves Canary::Eval::Runner's own contract against Canary::Providers::Fake
# and a real Canary::Verifier/Canary::Pool (cheap, no network): the render
# mode a caller asked for lands on every record, a provider failure and an
# extractor refusal both come back as distinguishable non-scores that never
# claim a passed verdict (R3), a genuine rollout - win or lose - is scored,
# and the fan-out is bounded by the configured Async::Semaphore limit while
# still overlapping for real.
class RunnerTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures/task", __dir__)
  VALID_CODE_RESPONSE = "Here you go:\n\n```ruby\nclass Adder\n  def self.call(a, b)\n    a + b\n  end\nend\n```\n"
  WRONG_CODE_RESPONSE = "```ruby\nclass Adder\n  def self.call(a, b)\n    a - b\n  end\nend\n```"
  NO_FENCE_RESPONSE = "Sure, here is the answer: Adder.call adds two numbers."
  # Same shape as prefilter_test.rb's own truncation fixture: a parse error
  # anchored at EOF, inside a fence the extractor hands through unclosed
  # (extractor.rb:43-51) rather than refusing.
  TRUNCATED_CODE_RESPONSE = "```ruby\ndef foo\n  a = 1\n  if a"
  # A mid-file break (not anchored at EOF) - structurally invalid, but NOT
  # truncated, so this must stay a scored failure, not a non-score.
  MID_FILE_BREAK_RESPONSE = "```ruby\nclass Adder\n  def self.call(a, b)\n    @x = = 1\n  end\nend\n```"

  def test_fans_out_over_models_and_k_and_defaults_to_hidden_mode
    sampler = build_sampler(success_fake(VALID_CODE_RESPONSE))
    runner = Canary::Eval::Runner.new(sampler: sampler)

    records = runner.call(entries: [build_entry], models: ["fixture-model"], k: 2, grader: false)

    assert_equal 2, records.size
    assert_equal [0, 1], records.map(&:sample_index).sort
    records.each do |record|
      assert_equal Canary::Eval::Runner::SCHEMA_VERSION, record.schema_version
      assert_equal "eval_fixture_task", record.task_name
      assert_equal "fixture-model", record.model
      assert_equal :hidden, record.render_mode
      assert record.scored?
      assert_nil record.non_score_reason
      assert record.passed
    end
  end

  # AC6: a k>1 run's completions on disk (written by Sampler's own
  # RecordSink, no Fiber hop involved) must be joinable 1:1 to the Records
  # Runner returns for the same run - proving Sampler#call's base_index
  # (sampler.rb) carries job.index all the way to what lands on disk.
  def test_a_k3_run_produces_completions_joinable_1to1_to_records_by_sample_index
    completions_path = Tempfile.new(%w[runner_join_completions .jsonl]).path
    sampler = Canary::Sampler.new(
      provider: success_fake(VALID_CODE_RESPONSE),
      budget: Canary::Sampler::Budget.new(max_samples: 20),
      record_sink: Canary::Sampler::RecordSink.new(path: completions_path)
    )
    runner = Canary::Eval::Runner.new(sampler: sampler)

    records = runner.call(entries: [build_entry], models: ["fixture-model"], k: 3, grader: false)
    completions = File.readlines(completions_path).map { |line| JSON.parse(line) }

    assert_equal 3, completions.size
    joined = records.map do |record|
      completions.find do |completion|
        completion["task_name"] == record.task_name &&
          completion["model"] == record.model &&
          completion["mode"] == record.render_mode.to_s &&
          completion["sample_index"] == record.sample_index
      end
    end

    refute_includes joined, nil
    assert_equal records.map(&:sample_index).sort, completions.map { |c| c["sample_index"] }.sort
  end

  def test_grader_true_produces_grader_visible_records
    sampler = build_sampler(success_fake(VALID_CODE_RESPONSE))
    runner = Canary::Eval::Runner.new(sampler: sampler)

    records = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: true)

    assert_equal :grader_visible, records.first.render_mode
  end

  def test_a_provider_failure_is_a_non_score_never_a_passed_verdict
    fake = Canary::Providers::Fake.new { |model:, prompt:| Dry::Monads::Failure(Canary::Providers::Error.new(reason: :refusal, message: "no")) }
    runner = Canary::Eval::Runner.new(sampler: build_sampler(fake))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    refute record.scored?
    assert_equal :refusal, record.non_score_reason
    assert_nil record.passed
  end

  def test_an_extractor_refusal_is_a_non_score_never_a_passed_verdict
    runner = Canary::Eval::Runner.new(sampler: build_sampler(success_fake(NO_FENCE_RESPONSE)))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    refute record.scored?
    assert_equal :extractor_refusal, record.non_score_reason
    assert_equal :no_fenced_code, record.extractor_outcome
    assert_nil record.passed
  end

  def test_code_that_fails_the_grader_is_scored_false_not_a_non_score
    runner = Canary::Eval::Runner.new(sampler: build_sampler(success_fake(WRONG_CODE_RESPONSE)))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    assert record.scored?
    assert_nil record.non_score_reason
    refute record.passed
    assert record.prefilter_clean
    assert_equal :ok, record.rollout_outcome
    assert_equal 0, record.passed_examples
    assert_equal 2, record.total_examples
  end

  def test_concurrency_never_exceeds_the_configured_bound_and_genuinely_overlaps
    concurrent = 0
    max_concurrent = 0

    fake = Canary::Providers::Fake.new do |model:, prompt:|
      concurrent += 1
      max_concurrent = concurrent if concurrent > max_concurrent
      Async::Task.current.sleep(0.01)
      concurrent -= 1
      Dry::Monads::Success(Canary::Providers::Sample.new(text: VALID_CODE_RESPONSE, raw: {usage: {input_tokens: 1, output_tokens: 1}}, stop_reason: :end_turn))
    end
    runner = Canary::Eval::Runner.new(sampler: build_sampler(fake, max_samples: 10), concurrency: 3)

    records = runner.call(entries: [build_entry], models: ["fixture-model"], k: 10, grader: false)

    assert_equal 10, records.size
    assert_operator max_concurrent, :<=, 3
    assert_operator max_concurrent, :>, 1, "expected genuine overlap under the semaphore, not accidental sequencing"
  end

  # Runner#call never returns to the caller here - the raise propagates out
  # of Sync - so the only way a record can be sitting on disk after rescue
  # is if the on_record callback wrote it there DURING the run, not from
  # Runner#call's return value (I15 F2: an exception on a later call must
  # not cost already-completed, already-paid-for samples).
  def test_incremental_records_reach_disk_even_when_a_job_raises_mid_run
    sink_file = Tempfile.new(%w[incremental_records .jsonl])
    call_count = 0
    fake = Canary::Providers::Fake.new do |model:, prompt:|
      call_count += 1
      raise "boom on call #{call_count}" if call_count == 3
      Dry::Monads::Success(Canary::Providers::Sample.new(text: VALID_CODE_RESPONSE, raw: {usage: {input_tokens: 1, output_tokens: 1}}, stop_reason: :end_turn))
    end
    runner = Canary::Eval::Runner.new(sampler: build_sampler(fake, max_samples: 10), concurrency: 1)

    assert_raises(RuntimeError) do
      runner.call(entries: [build_entry], models: ["fixture-model"], k: 5, grader: false) do |record|
        File.open(sink_file.path, "a") { |f| f.puts(JSON.generate(record.to_h)) }
      end
    end

    on_disk = File.readlines(sink_file.path).map { |line| JSON.parse(line) }
    refute_empty on_disk
    assert_operator on_disk.size, :<, 5, "the job that raised must not itself have yielded a record"
    assert(on_disk.all? { |r| r["scored"] })
  ensure
    sink_file&.unlink
  end

  # AC6(a): an EOF-anchored prefilter truncation on a clean stop (:end_turn)
  # is the model's own doing, not a harness cutoff - it must not be labeled
  # :truncated.
  def test_a_prefilter_reject_caused_by_eof_truncation_on_a_clean_stop_is_a_distinct_non_score
    runner = Canary::Eval::Runner.new(sampler: build_sampler(success_fake(TRUNCATED_CODE_RESPONSE)))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    refute record.scored?
    assert_equal :premature_stop, record.non_score_reason
    assert_nil record.passed
    assert_equal :end_turn, record.stop_reason
  end

  # AC6(b): the same EOF-anchored prefilter truncation on a cutoff stop
  # (:max_tokens) IS an honest :truncated - the provider evidenced the
  # cutoff itself.
  def test_a_prefilter_reject_caused_by_eof_truncation_on_a_cutoff_stop_is_truncated
    fake = Canary::Providers::Fake.new { |model:, prompt:| Dry::Monads::Success(Canary::Providers::Sample.new(text: TRUNCATED_CODE_RESPONSE, raw: {usage: {input_tokens: 1, output_tokens: 1}}, stop_reason: :max_tokens)) }
    runner = Canary::Eval::Runner.new(sampler: build_sampler(fake))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    refute record.scored?
    assert_equal :truncated, record.non_score_reason
    assert_nil record.passed
  end

  def test_a_prefilter_reject_not_caused_by_truncation_stays_a_scored_failure
    runner = Canary::Eval::Runner.new(sampler: build_sampler(success_fake(MID_FILE_BREAK_RESPONSE)))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    assert record.scored?
    assert_nil record.non_score_reason
    refute record.passed
  end

  # AC7's four branches: a provider Failure whose error.text is non-nil gets
  # the identical shot at the grader a Success gets, honestly, without ever
  # widening the provider's own monad arm into a Success.

  def test_a_truncated_failure_with_parseable_content_is_graded_scored_true_with_honest_stop_reason
    runner = Canary::Eval::Runner.new(sampler: build_sampler(truncated_failure_fake(VALID_CODE_RESPONSE)))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    assert record.scored?
    assert_nil record.non_score_reason
    assert record.passed
    assert_equal :max_tokens, record.stop_reason
  end

  def test_a_truncated_failure_with_no_text_is_a_non_score_unchanged
    fake = Canary::Providers::Fake.new { |model:, prompt:| Dry::Monads::Failure(Canary::Providers::Error.new(reason: :truncated, message: "response truncated", raw: {stop_reason: :max_tokens})) }
    runner = Canary::Eval::Runner.new(sampler: build_sampler(fake))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    refute record.scored?
    assert_equal :truncated, record.non_score_reason
    assert_nil record.passed
  end

  def test_a_truncated_failure_with_unparseable_text_is_a_non_score
    runner = Canary::Eval::Runner.new(sampler: build_sampler(truncated_failure_fake(TRUNCATED_CODE_RESPONSE)))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    refute record.scored?
    assert_equal :truncated, record.non_score_reason
    assert_nil record.passed
  end

  def test_a_refusal_failure_with_visible_text_routes_through_the_same_graded_path_honestly
    fake = Canary::Providers::Fake.new do |model:, prompt:|
      Dry::Monads::Failure(Canary::Providers::Error.new(
        reason: :refusal, message: "provider refused",
        raw: {stop_reason: :refusal, usage: {input_tokens: 1, output_tokens: 1}},
        text: VALID_CODE_RESPONSE
      ))
    end
    runner = Canary::Eval::Runner.new(sampler: build_sampler(fake))

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    assert record.scored?
    assert_nil record.non_score_reason
    assert record.passed
    assert_equal :refusal, record.stop_reason
  end

  # A time-vs-accuracy comparison needs a per-sample duration, and it has to
  # be on every record: a refusal that took four minutes and one that took
  # four seconds are different findings, and only one of them is the model
  # being fast.
  def test_every_record_carries_the_wall_time_of_its_attempt
    sampler = build_sampler(success_fake(VALID_CODE_RESPONSE))
    runner = Canary::Eval::Runner.new(sampler: sampler)

    records = runner.call(entries: [build_entry], models: ["fixture-model"], k: 2, grader: false)

    refute_empty records
    records.each do |record|
      refute_nil record.sample_ms, "#{record.task_name} carries no sample_ms"
      assert_kind_of Integer, record.sample_ms
      assert_operator record.sample_ms, :>=, 0
    end
  end

  # A non-scored record needs the duration just as much: a four-minute
  # refusal and a four-second one are different findings.
  def test_a_non_scored_record_still_carries_its_wall_time
    sampler = build_sampler(success_fake("no fenced code here at all"))
    runner = Canary::Eval::Runner.new(sampler: sampler)

    record = runner.call(entries: [build_entry], models: ["fixture-model"], k: 1, grader: false).first

    refute record.scored?
    refute_nil record.sample_ms
  end

  # A batching engine answers concurrent identical prompts once and repeats
  # it, so the k samples of a task must not be schedulable together. Order is
  # the guard: every task's sample 0 is emitted before any task's sample 1.
  def test_samples_of_one_task_are_never_adjacent_in_the_schedule
    order = []
    sampler = build_sampler(success_fake(VALID_CODE_RESPONSE))
    runner = Canary::Eval::Runner.new(sampler: sampler, concurrency: 1)

    runner.call(entries: [build_entry("a"), build_entry("b")], models: ["m"], k: 3, grader: false) do |record|
      order << [record.task_name, record.sample_index]
    end

    indices = order.map(&:last)

    assert_equal [0, 0, 1, 1, 2, 2], indices, "schedule must be sample-major, not task-major"
  end

  private

  def truncated_failure_fake(text)
    Canary::Providers::Fake.new do |model:, prompt:|
      Dry::Monads::Failure(Canary::Providers::Error.new(
        reason: :truncated, message: "response truncated: stop_reason=max_tokens",
        raw: {stop_reason: :max_tokens, usage: {input_tokens: 1, output_tokens: 1}},
        text: text
      ))
    end
  end

  def success_fake(text)
    Canary::Providers::Fake.new { |model:, prompt:| Dry::Monads::Success(Canary::Providers::Sample.new(text: text, raw: {usage: {input_tokens: 1, output_tokens: 1}}, stop_reason: :end_turn)) }
  end

  def build_sampler(provider, max_samples: 20)
    Canary::Sampler.new(
      provider: provider,
      budget: Canary::Sampler::Budget.new(max_samples: max_samples),
      record_sink: Canary::Sampler::RecordSink.new(path: Tempfile.new(%w[runner_test_records .jsonl]).path)
    )
  end

  def build_entry(name = "eval_fixture_task")
    Canary::TaskRepo::Entry.new(
      name: name,
      statement: "Implement Adder.call(a, b), returning their sum.",
      adapter: :minitest,
      reference: Canary::Task.new(solution_path: File.join(FIXTURES, "solution.rb"), test_path: File.join(FIXTURES, "grader.rb"), adapter: :minitest)
    )
  end
end
