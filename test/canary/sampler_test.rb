require "test_helper"
require "json"
require "tempfile"

# Proves Canary::Sampler's own contract: the budget guard blocks the
# provider before it is ever invoked (not just before it "succeeds"),
# every request that IS dispatched gets recorded together with its render
# mode, model is a required parameter with no baked-in default, and the
# real Anthropic provider's transport-failure path works against the real
# gem/error hierarchy without ever completing a live call. Built on this
# test's own fixtures under sampler_fixtures/, not on tasks/**, since a
# concurrent lane owns tasks/**.
class SamplerTest < Minitest::Test
  FIXTURES = File.expand_path("sampler_fixtures", __dir__)

  def setup
    @entry = build_entry
    @record_path = Tempfile.new(%w[sampler_records .jsonl]).path
  end

  def test_samples_come_back_as_dry_monads_results_and_the_provider_is_called_once_per_sample
    fake = Canary::Providers::Fake.new
    sampler = build_sampler(provider: fake, max_samples: 5)

    results = sampler.call(@entry, model: "claude-fixture-model", n: 3)

    assert_equal 3, results.size
    assert results.all? { |r| r.is_a?(Dry::Monads::Result) }
    assert results.all?(&:success?)
    assert_equal 3, fake.calls.size
  end

  def test_budget_guard_returns_failure_before_the_provider_is_invoked
    fake = Canary::Providers::Fake.new
    sampler = build_sampler(provider: fake, max_samples: 1)

    results = sampler.call(@entry, model: "claude-fixture-model", n: 2)

    assert results[0].success?
    assert results[1].failure?
    assert_equal :budget_exhausted, results[1].failure.reason
    assert_equal 1, fake.calls.size
  end

  def test_budget_guard_blocks_every_sample_when_already_exhausted
    fake = Canary::Providers::Fake.new
    sampler = build_sampler(provider: fake, max_samples: 0)

    results = sampler.call(@entry, model: "claude-fixture-model", n: 2)

    assert results.all?(&:failure?)
    assert results.all? { |r| r.failure.reason == :budget_exhausted }
    assert_empty fake.calls
  end

  def test_model_is_a_required_parameter_with_no_default
    sampler = build_sampler(provider: Canary::Providers::Fake.new, max_samples: 1)

    assert_raises(ArgumentError) { sampler.call(@entry) }
  end

  def test_every_dispatched_request_is_recorded_with_its_render_mode
    fake = Canary::Providers::Fake.new
    sampler = build_sampler(provider: fake, max_samples: 5)

    sampler.call(@entry, model: "claude-fixture-model", n: 1)
    sampler.call(@entry, model: "claude-fixture-model", n: 1, grader: true)

    hidden, grader_visible = read_records
    assert_equal "hidden", hidden["mode"]
    assert_equal "grader_visible", grader_visible["mode"]

    [hidden, grader_visible].each do |record|
      assert_equal "claude-fixture-model", record["model"]
      assert_equal @entry.name, record["task_name"]
      assert_equal 0, record["sample_index"]
      refute_nil record["response"]
    end
  end

  def test_a_budget_blocked_sample_is_never_recorded
    fake = Canary::Providers::Fake.new
    sampler = build_sampler(provider: fake, max_samples: 0)

    sampler.call(@entry, model: "claude-fixture-model", n: 1)

    assert_empty read_records
  end

  def test_a_provider_failure_is_still_recorded
    fake = Canary::Providers::Fake.new { |model:, prompt:| Dry::Monads::Failure(Canary::Providers::Error.new(reason: :refusal, message: "no")) }
    sampler = build_sampler(provider: fake, max_samples: 5)

    sampler.call(@entry, model: "claude-fixture-model", n: 1)

    record = read_records.first
    assert_equal "refusal", record["response"]["reason"]
  end

  def test_anthropic_provider_returns_a_transport_failure_without_a_live_call
    client = Anthropic::Client.new(api_key: "sk-fixture-not-a-real-key", base_url: "http://127.0.0.1:1", max_retries: 0)
    provider = Canary::Providers::Anthropic.new(client: client)

    result = provider.sample(model: "claude-fixture-model", prompt: "hello")

    assert result.failure?
    assert_equal :transport_error, result.failure.reason
    assert_includes result.failure.message, "APIConnectionError"
  end

  private

  def build_sampler(provider:, max_samples:)
    Canary::Sampler.new(
      provider: provider,
      budget: Canary::Sampler::Budget.new(max_samples: max_samples),
      record_sink: Canary::Sampler::RecordSink.new(path: @record_path)
    )
  end

  def read_records
    File.readlines(@record_path).map { |line| JSON.parse(line) }
  end

  def build_entry
    dir = File.join(FIXTURES, "task")
    Canary::TaskRepo::Entry.new(
      name: "sampler_fixture_task",
      statement: "Implement Widget.wrap, a module method that returns Widget itself.",
      reference: Canary::Task.new(solution_path: File.join(dir, "solution.rb"), test_path: File.join(dir, "grader.rb"), adapter: :minitest)
    )
  end
end
