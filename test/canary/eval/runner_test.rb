require "test_helper"
require "async"
require "tempfile"

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

  def test_fans_out_over_models_and_k_and_defaults_to_hidden_mode
    sampler = build_sampler(success_fake(VALID_CODE_RESPONSE))
    runner = Canary::Eval::Runner.new(sampler: sampler)

    records = runner.call(entries: [build_entry], models: ["fixture-model"], k: 2, grader: false)

    assert_equal 2, records.size
    assert_equal [0, 1], records.map(&:sample_index).sort
    records.each do |record|
      assert_equal 1, record.schema_version
      assert_equal "eval_fixture_task", record.task_name
      assert_equal "fixture-model", record.model
      assert_equal :hidden, record.render_mode
      assert record.scored?
      assert_nil record.non_score_reason
      assert record.passed
    end
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
      Dry::Monads::Success(Canary::Providers::Sample.new(text: VALID_CODE_RESPONSE, raw: {stop_reason: :end_turn, usage: {input_tokens: 1, output_tokens: 1}}))
    end
    runner = Canary::Eval::Runner.new(sampler: build_sampler(fake, max_samples: 10), concurrency: 3)

    records = runner.call(entries: [build_entry], models: ["fixture-model"], k: 10, grader: false)

    assert_equal 10, records.size
    assert_operator max_concurrent, :<=, 3
    assert_operator max_concurrent, :>, 1, "expected genuine overlap under the semaphore, not accidental sequencing"
  end

  private

  def success_fake(text)
    Canary::Providers::Fake.new { |model:, prompt:| Dry::Monads::Success(Canary::Providers::Sample.new(text: text, raw: {stop_reason: :end_turn, usage: {input_tokens: 1, output_tokens: 1}})) }
  end

  def build_sampler(provider, max_samples: 20)
    Canary::Sampler.new(
      provider: provider,
      budget: Canary::Sampler::Budget.new(max_samples: max_samples),
      record_sink: Canary::Sampler::RecordSink.new(path: Tempfile.new(%w[runner_test_records .jsonl]).path)
    )
  end

  def build_entry
    Canary::TaskRepo::Entry.new(
      name: "eval_fixture_task",
      statement: "Implement Adder.call(a, b), returning their sum.",
      adapter: :minitest,
      reference: Canary::Task.new(solution_path: File.join(FIXTURES, "solution.rb"), test_path: File.join(FIXTURES, "grader.rb"), adapter: :minitest)
    )
  end
end
