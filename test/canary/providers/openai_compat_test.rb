require "test_helper"
require "json"
require "socket"

# Proves Canary::Providers::OpenAICompat's own contract: every
# finish_reason branch AC3 names, offline against an injected transport
# (no mocking the class under test - the transport is the seam), the
# request's bearer header and URL construction, usage tokens surfaced,
# and raw preserved on both monad arms.
class OpenAICompatTest < Minitest::Test
  BASE_URL = "https://example-provider.test/v1"

  def test_finish_reason_stop_with_text_is_a_success
    provider = build_provider(response_for(finish_reason: "stop", content: "the answer"))

    result = provider.sample(model: "m", prompt: "p")

    assert result.success?
    assert_equal "the answer", result.success.text
    assert_equal :stop, result.success.stop_reason
  end

  def test_finish_reason_length_is_a_truncated_failure
    provider = build_provider(response_for(finish_reason: "length", content: "cut off mid"))

    result = provider.sample(model: "m", prompt: "p", max_tokens: 64)

    assert result.failure?
    assert_equal :truncated, result.failure.reason
    assert_includes result.failure.message, "length"
    assert_includes result.failure.message, "64"
  end

  # AC6: the truncated response's own visible text travels on Error#text
  # rather than being reduced to a reason code.
  def test_finish_reason_length_carries_the_responses_visible_text
    provider = build_provider(response_for(finish_reason: "length", content: "cut off mid"))

    result = provider.sample(model: "m", prompt: "p")

    assert_equal "cut off mid", result.failure.text
  end

  def test_finish_reason_content_filter_is_a_refusal_failure
    provider = build_provider(response_for(finish_reason: "content_filter", content: nil))

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :refusal, result.failure.reason
  end

  def test_finish_reason_content_filter_with_no_content_carries_nil_text
    provider = build_provider(response_for(finish_reason: "content_filter", content: nil))

    result = provider.sample(model: "m", prompt: "p")

    assert_nil result.failure.text
  end

  def test_finish_reason_content_filter_with_visible_text_carries_it
    provider = build_provider(response_for(finish_reason: "content_filter", content: "here is what I have so far"))

    result = provider.sample(model: "m", prompt: "p")

    assert_equal "here is what I have so far", result.failure.text
  end

  def test_an_absent_finish_reason_is_a_content_failure
    provider = build_provider(response_for(finish_reason: nil, content: "something"))

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :unexpected_finish_reason, result.failure.reason
    assert_equal "something", result.failure.text
  end

  def test_a_tool_calls_finish_reason_is_a_content_failure
    provider = build_provider(response_for(finish_reason: "tool_calls", content: nil))

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :unexpected_finish_reason, result.failure.reason
  end

  def test_an_unrecognized_finish_reason_is_a_content_failure
    provider = build_provider(response_for(finish_reason: "some_new_provider_thing", content: "text"))

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :unexpected_finish_reason, result.failure.reason
    assert_includes result.failure.message, "some_new_provider_thing"
  end

  def test_empty_content_despite_finish_reason_stop_is_a_content_failure_not_a_success
    provider = build_provider(response_for(finish_reason: "stop", content: ""))

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :empty_completion, result.failure.reason
    assert_nil result.failure.text
  end

  def test_nil_content_despite_finish_reason_stop_is_a_content_failure_not_a_success
    provider = build_provider(response_for(finish_reason: "stop", content: nil))

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :empty_completion, result.failure.reason
    assert_nil result.failure.text
  end

  def test_usage_tokens_are_surfaced_on_success
    provider = build_provider(response_for(finish_reason: "stop", content: "hi", prompt_tokens: 12, completion_tokens: 34))

    result = provider.sample(model: "m", prompt: "p")

    assert_equal 12, result.success.raw.dig(:usage, :input_tokens)
    assert_equal 34, result.success.raw.dig(:usage, :output_tokens)
  end

  def test_raw_is_preserved_on_success
    body = response_for(finish_reason: "stop", content: "hi", id: "chatcmpl-abc123")
    provider = build_provider(body)

    result = provider.sample(model: "m", prompt: "p")

    assert_equal "chatcmpl-abc123", result.success.raw[:id]
  end

  def test_raw_is_preserved_on_a_content_failure
    body = response_for(finish_reason: "length", content: "partial", id: "chatcmpl-xyz789")
    provider = build_provider(body)

    result = provider.sample(model: "m", prompt: "p")

    assert_equal "chatcmpl-xyz789", result.failure.raw[:id]
    assert_equal :length, result.failure.raw[:stop_reason]
  end

  def test_bearer_header_and_url_construction_without_network
    calls = []
    transport = ->(uri:, headers:, body:) {
      calls << {uri: uri, headers: headers, body: body}
      fake_response(200, response_for(finish_reason: "stop", content: "hi"))
    }
    provider = Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "sk-test-key", transport: transport)

    provider.sample(model: "some-model", prompt: "hello there")

    assert_equal 1, calls.size
    assert_equal "#{BASE_URL}/chat/completions", calls.first[:uri].to_s
    assert_equal "Bearer sk-test-key", calls.first[:headers]["Authorization"]

    sent = JSON.parse(calls.first[:body], symbolize_names: true)
    assert_equal "some-model", sent[:model]
    assert_equal [{role: "user", content: "hello there"}], sent[:messages]
  end

  # The bug this guards: with no temperature in the body, a backend that
  # decodes greedily by default (mlx-vlm) returns byte-identical text for
  # every sample, turning a k=3 sweep into a k=1 sweep billed three times.
  # Stating temperature is what fixes it; the seed only makes the variation
  # reproducible.
  def test_sampling_is_stated_on_the_request_rather_than_left_to_the_server
    calls = []
    transport = ->(uri:, headers:, body:) {
      calls << body
      fake_response(200, response_for(finish_reason: "stop", content: "hi"))
    }
    provider = Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "k", transport: transport)

    provider.sample(model: "m", prompt: "p")

    sent = JSON.parse(calls.first, symbolize_names: true)
    assert_equal Canary::Providers::OpenAICompat::DEFAULT_TEMPERATURE, sent[:temperature]
    assert_operator sent[:temperature], :>, 0, "a zero temperature decodes greedily and collapses k>1 to k=1"
  end

  def test_seed_follows_the_sample_index_so_the_k_samples_of_a_task_differ
    calls = []
    transport = ->(uri:, headers:, body:) {
      calls << body
      fake_response(200, response_for(finish_reason: "stop", content: "hi"))
    }
    provider = Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "k", transport: transport)

    3.times { |index| provider.sample(model: "m", prompt: "p", sample_index: index) }

    seeds = calls.map { |body| JSON.parse(body, symbolize_names: true)[:seed] }

    assert_equal [0, 1, 2], seeds
    assert_equal seeds.uniq.size, seeds.size, "a repeated seed asks for the same completion twice"
  end

  def test_temperature_is_overridable_per_instance_and_per_model
    calls = []
    transport = ->(uri:, headers:, body:) {
      calls << body
      fake_response(200, response_for(finish_reason: "stop", content: "hi"))
    }
    provider = Canary::Providers::OpenAICompat.new(
      base_url: BASE_URL, api_key: "k", transport: transport, temperature: 0.2,
      extra_body_by_model: {"card-model" => {temperature: 0.7, top_p: 0.95}}
    )

    provider.sample(model: "plain-model", prompt: "p")
    provider.sample(model: "card-model", prompt: "p")

    assert_in_delta 0.2, JSON.parse(calls.first, symbolize_names: true)[:temperature]

    carded = JSON.parse(calls.last, symbolize_names: true)

    assert_in_delta 0.7, carded[:temperature]
    assert_in_delta 0.95, carded[:top_p]
  end

  def test_extra_body_by_model_is_merged_into_the_request_for_a_matching_model
    calls = []
    transport = ->(uri:, headers:, body:) {
      calls << body
      fake_response(200, response_for(finish_reason: "stop", content: "hi"))
    }
    provider = Canary::Providers::OpenAICompat.new(
      base_url: BASE_URL, api_key: "sk-test-key", transport: transport,
      extra_body_by_model: {"reasoning-model" => {reasoning: {effort: "low"}}}
    )

    provider.sample(model: "reasoning-model", prompt: "p")

    sent = JSON.parse(calls.first, symbolize_names: true)
    assert_equal({effort: "low"}, sent[:reasoning])
  end

  def test_extra_body_by_model_is_a_no_op_for_a_model_with_no_entry
    calls = []
    transport = ->(uri:, headers:, body:) {
      calls << body
      fake_response(200, response_for(finish_reason: "stop", content: "hi"))
    }
    provider = Canary::Providers::OpenAICompat.new(
      base_url: BASE_URL, api_key: "sk-test-key", transport: transport,
      extra_body_by_model: {"reasoning-model" => {reasoning: {effort: "low"}}}
    )

    provider.sample(model: "plain-model", prompt: "p")

    sent = JSON.parse(calls.first, symbolize_names: true)
    refute sent.key?(:reasoning)
    assert_equal "plain-model", sent[:model]
  end

  def test_a_non_2xx_status_is_a_transport_failure
    transport = ->(uri:, headers:, body:) { fake_response(401, {error: {message: "unauthorized"}}) }
    provider = Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "bad-key", transport: transport)

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :transport_error, result.failure.reason
  end

  # AC7/I19 F4: the Qwen privacy-404 diagnosis had to re-buy this evidence
  # once already because it was dropped here - a non-2xx response body must
  # survive on Error#raw exactly like every other failure shape on this
  # boundary.
  def test_a_non_2xx_status_preserves_the_response_body_on_raw
    transport = ->(uri:, headers:, body:) { fake_response(404, {error: {message: "no endpoints found matching your data policy"}}) }
    provider = Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "bad-key", transport: transport)

    result = provider.sample(model: "m", prompt: "p")

    assert_equal({error: {message: "no endpoints found matching your data policy"}}, result.failure.raw)
  end

  def test_a_non_2xx_status_with_a_non_json_body_wraps_it_on_raw_rather_than_dropping_it
    transport = ->(uri:, headers:, body:) { fake_raw_response(502, "<html>Bad Gateway</html>") }
    provider = Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "bad-key", transport: transport)

    result = provider.sample(model: "m", prompt: "p")

    assert_equal({body: "<html>Bad Gateway</html>"}, result.failure.raw)
  end

  def test_a_connection_failure_is_a_transport_failure_without_a_live_call
    provider = Canary::Providers::OpenAICompat.new(base_url: "http://127.0.0.1:1", api_key: "sk-fixture-not-a-real-key")

    result = provider.sample(model: "m", prompt: "hello")

    assert result.failure?
    assert_equal :transport_error, result.failure.reason
  end

  # AC7: the rescue in #sample names only the transport/parse error classes
  # it actually expects - anything else (a bug, not a transport failure)
  # must propagate rather than be swallowed as a content failure.
  def test_an_unexpected_error_from_the_transport_propagates_rather_than_being_caught
    transport = ->(uri:, headers:, body:) { raise ArgumentError, "boom" }
    provider = Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "sk-fixture", transport: transport)

    assert_raises(ArgumentError) { provider.sample(model: "m", prompt: "p") }
  end

  # AC5 (I27): the default read timeout is unchanged from before this
  # constant existed - every hosted caller (OpenRouter, Fireworks) that
  # constructs without a read_timeout: keyword keeps today's 60s behavior.
  def test_default_read_timeout_is_unchanged_at_sixty_seconds
    assert_equal 60, Canary::Providers::OpenAICompat::DEFAULT_READ_TIMEOUT
  end

  # AC5: proves read_timeout: actually threads through to the real (default)
  # transport, not just that the constructor accepts it - a TCP server that
  # accepts the connection but never writes a response forces the read to
  # block until read_timeout fires. Localhost only, no live provider call.
  def test_a_caller_set_read_timeout_is_honored_by_the_default_transport
    server = TCPServer.new("127.0.0.1", 0)
    port = server.addr[1]
    provider = Canary::Providers::OpenAICompat.new(
      base_url: "http://127.0.0.1:#{port}", api_key: "sk-fixture", read_timeout: 0.2
    )

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :transport_error, result.failure.reason
    assert_includes result.failure.message, "Net::ReadTimeout"
  ensure
    server&.close
  end

  # The one live test in this file, and the pattern every live test in
  # this suite copies (sampler_test.rb): opt in with CANARY_LIVE, skip
  # loudly when the credential is absent - never let a missing key read
  # as a 401.
  def test_live_openrouter_completes_a_real_call
    skip "set CANARY_LIVE=1 to spend on the real API" unless ENV["CANARY_LIVE"]
    skip "CANARY_LIVE is set but no OPENROUTER_API_KEY was loaded - is .env present?" unless ENV["OPENROUTER_API_KEY"]

    provider = Canary::Providers::OpenAICompat.new(base_url: "https://openrouter.ai/api/v1", api_key: ENV["OPENROUTER_API_KEY"], max_tokens: 16)

    result = provider.sample(model: "openai/gpt-4o-mini", prompt: "Reply with the single word: canary")

    assert result.success?, "live call failed: #{result.failure&.message}"
    refute_empty result.success.text
  end

  # I19 F2: gpt-oss-20b @ max_tokens: 16 can never pass against a
  # reasoning-only catalog entry - it burns the whole budget on reasoning
  # before any visible text appears. deepseek-v4-flash is the model
  # bin/eval_sweep.rb's own Fireworks probe uses (AC8/Audit D), run here at
  # its configured reasoning effort and a budget with real margin over the
  # 64 tokens the sweep's own preflight already proved sufficient.
  def test_live_fireworks_completes_a_real_call
    skip "set CANARY_LIVE=1 to spend on the real API" unless ENV["CANARY_LIVE"]
    skip "CANARY_LIVE is set but no FIREWORKS_API_KEY was loaded - is .env present?" unless ENV["FIREWORKS_API_KEY"]

    model = "accounts/fireworks/models/deepseek-v4-flash"
    provider = Canary::Providers::OpenAICompat.new(
      base_url: "https://api.fireworks.ai/inference/v1", api_key: ENV["FIREWORKS_API_KEY"], max_tokens: 256,
      extra_body_by_model: {model => {reasoning_effort: "low"}}
    )

    result = provider.sample(model: model, prompt: "Reply with the single word: canary")

    assert result.success?, "live call failed: #{result.failure&.message}"
    refute_empty result.success.text
  end

  private

  def response_for(finish_reason:, content:, id: "chatcmpl-fixture", prompt_tokens: 10, completion_tokens: 20)
    {
      id: id,
      object: "chat.completion",
      model: "m",
      choices: [{index: 0, message: {role: "assistant", content: content}, finish_reason: finish_reason}],
      usage: {prompt_tokens: prompt_tokens, completion_tokens: completion_tokens, total_tokens: prompt_tokens + completion_tokens}
    }
  end

  def fake_response(status, body_hash)
    fake_raw_response(status, JSON.generate(body_hash))
  end

  def fake_raw_response(status, raw_body)
    Struct.new(:code, :body).new(status.to_s, raw_body)
  end

  def build_provider(body_hash)
    transport = ->(uri:, headers:, body:) { fake_response(200, body_hash) }
    Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "sk-fixture", transport: transport)
  end
end
