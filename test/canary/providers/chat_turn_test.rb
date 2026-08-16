require "test_helper"

class ChatTurnTest < Minitest::Test
  def test_tool_calls_defaults_to_an_empty_array
    turn = Canary::Providers::ChatTurn.new(message: {role: "assistant", content: "hi"}, finish_reason: :stop, raw: {})

    assert_equal [], turn.tool_calls
  end

  def test_carries_a_typed_tool_call
    call = Canary::Providers::ChatTurn::ToolCall.new(id: "c1", name: "ruby_eval", arguments: {code: "1"})
    turn = Canary::Providers::ChatTurn.new(message: {}, tool_calls: [call], finish_reason: :tool_calls, raw: {})

    assert_equal "ruby_eval", turn.tool_calls.first.name
    assert_equal({code: "1"}, turn.tool_calls.first.arguments)
  end

  def test_is_a_frozen_data_value
    turn = Canary::Providers::ChatTurn.new(message: {}, finish_reason: :stop, raw: {})

    assert turn.frozen?
  end
end
