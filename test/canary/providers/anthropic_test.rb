require "test_helper"

# Proves Canary::Providers::Anthropic's Error#text seam (AC6): a max_tokens
# truncation and a refusal both carry the response's visible text when it
# has any, nil when it doesn't, and a transport failure (no response at
# all) always carries nil. Built on inline Anthropic::Models::Message
# fixtures (no mocking the class under test) rather than sampler_test.rb's
# JSON fixtures, since that file belongs to a different lane's touch set.
class AnthropicTest < Minitest::Test
  def test_a_max_tokens_truncation_carries_the_responses_visible_text
    provider = Canary::Providers::Anthropic.new(client: client_returning(fixture_message(stop_reason: "max_tokens", content: [text_block("def foo\n  1")])))

    result = provider.sample(model: "claude-opus-5", prompt: "hello")

    assert result.failure?
    assert_equal :truncated, result.failure.reason
    assert_equal "def foo\n  1", result.failure.text
  end

  def test_a_refusal_with_visible_text_carries_it
    provider = Canary::Providers::Anthropic.new(client: client_returning(fixture_message(stop_reason: "refusal", content: [text_block("I can't help with that.")])))

    result = provider.sample(model: "claude-opus-5", prompt: "hello")

    assert result.failure?
    assert_equal :refusal, result.failure.reason
    assert_equal "I can't help with that.", result.failure.text
  end

  def test_a_refusal_with_no_content_blocks_carries_nil_text
    provider = Canary::Providers::Anthropic.new(client: client_returning(fixture_message(stop_reason: "refusal", content: [])))

    result = provider.sample(model: "claude-opus-5", prompt: "hello")

    assert result.failure?
    assert_nil result.failure.text
  end

  def test_a_transport_failure_carries_nil_text
    client = Anthropic::Client.new(api_key: "sk-fixture-not-a-real-key", base_url: "http://127.0.0.1:1", max_retries: 0)
    provider = Canary::Providers::Anthropic.new(client: client)

    result = provider.sample(model: "claude-fixture-model", prompt: "hello")

    assert result.failure?
    assert_equal :transport_error, result.failure.reason
    assert_nil result.failure.text
  end

  def test_a_success_still_carries_raw_unchanged
    provider = Canary::Providers::Anthropic.new(client: client_returning(fixture_message(stop_reason: "end_turn", content: [text_block("done")])))

    result = provider.sample(model: "claude-opus-5", prompt: "hello")

    assert result.success?
    assert_equal "done", result.success.text
    assert_equal :end_turn, result.success.raw[:stop_reason]
  end

  private

  def client_returning(response)
    messages = Struct.new(:message) { def create(**_kw) = message }.new(response)
    Struct.new(:messages).new(messages)
  end

  def text_block(text)
    {type: "text", text: text}
  end

  def fixture_message(stop_reason:, content:)
    Anthropic::Models::Message.new(
      id: "msg_fixture",
      content: content,
      model: "claude-opus-5",
      role: "assistant",
      stop_reason: stop_reason,
      stop_sequence: nil,
      type: "message",
      usage: {input_tokens: 10, output_tokens: 20}
    )
  end
end
