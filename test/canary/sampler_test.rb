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

  def test_a_max_tokens_stop_reason_is_a_truncated_failure_not_a_success
    provider = Canary::Providers::Anthropic.new(client: client_returning(load_response("truncated")))

    result = provider.sample(model: "claude-opus-5", prompt: "hello")

    assert result.failure?
    assert_equal :truncated, result.failure.reason
    assert_includes result.failure.message, "max_tokens"
  end

  # A truncated response is a Failure, but its text is still the only copy
  # of what the model actually wrote - and it is often recoverable, since
  # the cut usually lands in trailing prose after a complete fenced block
  # (the recorded claude-opus-5 sample is exactly that shape). Recording
  # only the reason code would make the sample unrecoverable after the
  # fact, so the response travels on the Failure and into the record.
  # The one test in the suite that spends money, and the pattern every live
  # test copies: opt in with CANARY_LIVE, skip loudly otherwise. Everything
  # else about the provider is proven against recorded fixtures - this exists
  # to catch the class of break a fixture cannot, where the real API changes
  # shape underneath us and every fixture-backed test stays green.
  def test_live_provider_completes_a_real_call
    # Both halves matter: CANARY_LIVE is the intent, a loaded key is the
    # capability. Checking only the flag turns a missing .env into a 401
    # failure that reads like a broken provider instead of an absent
    # credential - which is the confusing shape a worktree without the
    # symlink would otherwise hand a lane.
    skip "set CANARY_LIVE=1 to spend on the real API" unless ENV["CANARY_LIVE"]
    skip "CANARY_LIVE is set but no ANTHROPIC_API_KEY was loaded - is .env present?" unless ENV["ANTHROPIC_API_KEY"]

    provider = Canary::Providers::Anthropic.new(max_tokens: 16)

    result = provider.sample(model: "claude-haiku-4-5-20251001", prompt: "Reply with the single word: canary")

    assert result.success?, "live call failed: #{result.failure&.message}"
    refute_empty result.success.text
    assert_operator result.success.raw[:usage][:output_tokens], :<=, 16
  end

  def test_a_truncated_sample_records_the_response_not_just_the_reason
    provider = Canary::Providers::Anthropic.new(client: client_returning(load_response("truncated")))
    sampler = build_sampler(provider: provider, max_samples: 5)

    result = sampler.call(@entry, model: "claude-opus-5", n: 1).first

    assert_equal :truncated, result.failure.reason

    recorded = read_records.first["response"]
    assert_equal "truncated", recorded["reason"]
    refute_nil recorded["raw"], "a truncated response's text is the only copy there is"
    assert_includes Canary::Extractor.call(recorded["raw"]["content"].select { |b| b["type"] == "text" }.map { |b| b["text"] }.join).code, "Memoizer"
  end

  def test_a_failure_with_no_response_records_a_nil_raw
    fake = Canary::Providers::Fake.new
    sampler = build_sampler(provider: fake, max_samples: 0)

    result = sampler.call(@entry, model: "claude-fixture-model", n: 1).first

    assert_equal :budget_exhausted, result.failure.reason
    assert_nil result.failure.raw
  end

  # Real recorded shapes (see test/canary/sampler_fixtures/responses): a
  # single text block (haiku) and thinking-then-text (sonnet/opus/fable).
  # extract_text has to select the text block by +type+ rather than assume
  # position - reimplementing it as +content[0].text+ passes on the single-
  # block shape and raises NoMethodError on the thinking-block-first shape
  # (Anthropic::Models::ThinkingBlock has no +#text+), which is exactly what
  # this test catches.
  def test_extract_text_handles_both_live_response_shapes
    single = load_response("single_text_block")
    thinking_then_text = load_response("thinking_and_text")

    single_result = Canary::Providers::Anthropic.new(client: client_returning(single)).sample(model: "m", prompt: "p")
    thinking_result = Canary::Providers::Anthropic.new(client: client_returning(thinking_then_text)).sample(model: "m", prompt: "p")

    assert_equal single.content.first.text, single_result.success.text
    assert_equal thinking_then_text.content.select { |b| b.type == :text }.map(&:text).join, thinking_result.success.text
  end

  def test_spend_guard_lets_the_call_that_exceeds_it_complete_then_blocks_the_next_one
    usage = {input_tokens: 128, output_tokens: 1024}
    fake = Canary::Providers::Fake.new { |model:, prompt:| Dry::Monads::Success(Canary::Providers::Sample.new(text: "x", raw: {usage: usage})) }
    spend_guard = Canary::Sampler::SpendGuard.new(max_dollars: 5.0, price_table: {"claude-fixture-model" => {input_token_price: 0, output_token_price: 0.01}})
    sampler = Canary::Sampler.new(
      provider: fake,
      budget: Canary::Sampler::Budget.new(max_samples: 5),
      record_sink: Canary::Sampler::RecordSink.new(path: @record_path),
      spend_guard: spend_guard
    )

    results = sampler.call(@entry, model: "claude-fixture-model", n: 2)

    assert results[0].success?, "the call whose own cost pushes spend over the cap must still complete - cost is unknowable before it runs"
    assert results[1].failure?
    assert_equal :spend_exceeded, results[1].failure.reason
    assert_equal 1, fake.calls.size
  end

  def test_spend_guard_counts_thinking_tokens_as_ordinary_output_not_excluded
    usage = {input_tokens: 128, output_tokens: 1024, output_tokens_details: {thinking_tokens: 487}}
    price_table = {"m" => {input_token_price: 0, output_token_price: 0.075}}

    guard = Canary::Sampler::SpendGuard.new(max_dollars: 50.0, price_table: price_table)
    guard.record!(model: "m", usage: usage)

    # 1024 output tokens * $0.075 = $76.80, over the $50 cap. A price model
    # that excludes thinking would compute (1024 - 487) * $0.075 = $40.28,
    # under the cap - output_tokens_details is a read-only breakdown of an
    # already-inclusive output_tokens, not tokens to add or subtract.
    assert guard.exceeded?
  end

  def test_budget_and_spend_guard_are_independent_pre_flight_checks
    fake = Canary::Providers::Fake.new
    exhausted_spend_guard = Canary::Sampler::SpendGuard.new(max_dollars: -1, price_table: {})
    sampler = Canary::Sampler.new(
      provider: fake,
      budget: Canary::Sampler::Budget.new(max_samples: 5),
      record_sink: Canary::Sampler::RecordSink.new(path: @record_path),
      spend_guard: exhausted_spend_guard
    )

    result = sampler.call(@entry, model: "claude-fixture-model", n: 1).first

    assert result.failure?
    assert_equal :spend_exceeded, result.failure.reason
    assert_empty fake.calls
  end

  private

  def client_returning(message)
    messages = Struct.new(:message) { def create(**_kw) = message }.new(message)
    Struct.new(:messages).new(messages)
  end

  def load_response(name)
    path = File.join(FIXTURES, "responses", "#{name}.json")
    Anthropic::Models::Message.new(JSON.parse(File.read(path), symbolize_names: true))
  end

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
