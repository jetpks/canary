require "test_helper"
require "json"

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

  def test_finish_reason_content_filter_is_a_refusal_failure
    provider = build_provider(response_for(finish_reason: "content_filter", content: nil))

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :refusal, result.failure.reason
  end

  def test_an_absent_finish_reason_is_a_content_failure
    provider = build_provider(response_for(finish_reason: nil, content: "something"))

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :unexpected_finish_reason, result.failure.reason
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
  end

  def test_nil_content_despite_finish_reason_stop_is_a_content_failure_not_a_success
    provider = build_provider(response_for(finish_reason: "stop", content: nil))

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :empty_completion, result.failure.reason
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

  def test_a_non_2xx_status_is_a_transport_failure
    transport = ->(uri:, headers:, body:) { fake_response(401, {error: {message: "unauthorized"}}) }
    provider = Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "bad-key", transport: transport)

    result = provider.sample(model: "m", prompt: "p")

    assert result.failure?
    assert_equal :transport_error, result.failure.reason
  end

  def test_a_connection_failure_is_a_transport_failure_without_a_live_call
    provider = Canary::Providers::OpenAICompat.new(base_url: "http://127.0.0.1:1", api_key: "sk-fixture-not-a-real-key")

    result = provider.sample(model: "m", prompt: "hello")

    assert result.failure?
    assert_equal :transport_error, result.failure.reason
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

  def test_live_fireworks_completes_a_real_call
    skip "set CANARY_LIVE=1 to spend on the real API" unless ENV["CANARY_LIVE"]
    skip "CANARY_LIVE is set but no FIREWORKS_API_KEY was loaded - is .env present?" unless ENV["FIREWORKS_API_KEY"]

    provider = Canary::Providers::OpenAICompat.new(base_url: "https://api.fireworks.ai/inference/v1", api_key: ENV["FIREWORKS_API_KEY"], max_tokens: 16)

    result = provider.sample(model: "accounts/fireworks/models/gpt-oss-20b", prompt: "Reply with the single word: canary")

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
    Struct.new(:code, :body).new(status.to_s, JSON.generate(body_hash))
  end

  def build_provider(body_hash)
    transport = ->(uri:, headers:, body:) { fake_response(200, body_hash) }
    Canary::Providers::OpenAICompat.new(base_url: BASE_URL, api_key: "sk-fixture", transport: transport)
  end
end
