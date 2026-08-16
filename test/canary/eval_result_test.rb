require "test_helper"

class EvalResultTest < Minitest::Test
  def test_defaults_are_an_ok_outcome_with_no_value_no_exception_and_empty_output
    result = Canary::EvalResult.new

    assert result.ok?
    assert_nil result.value
    assert_nil result.exception
    assert_equal "", result.stdout
    assert_equal "", result.stderr
    assert_nil result.error
  end

  def test_the_outcome_predicates_match_the_outcome_they_name
    assert Canary::EvalResult.new(outcome: :ok).ok?
    assert Canary::EvalResult.new(outcome: :raised).raised?
    assert Canary::EvalResult.new(outcome: :timeout).timeout?
    assert Canary::EvalResult.new(outcome: :crash).crash?
    refute Canary::EvalResult.new(outcome: :raised).ok?
  end

  def test_value_keeps_its_own_class_and_inspect_rather_than_the_shadowed_field_names
    value = Canary::EvalResult::Value.new(class_name: "Integer", inspect_text: "42", truncated: false)

    assert_equal Canary::EvalResult::Value, value.class
    assert_match(/class_name="Integer"/, value.inspect)
  end

  def test_raised_carries_the_exceptions_class_name_and_message
    raised = Canary::EvalResult::Raised.new(class_name: "ArgumentError", message: "boom")

    assert_equal "ArgumentError", raised.class_name
    assert_equal "boom", raised.message
  end

  def test_a_result_and_its_nested_value_survive_a_marshal_round_trip
    result = Canary::EvalResult.new(
      outcome: :ok,
      value: Canary::EvalResult::Value.new(class_name: "Integer", inspect_text: "42", truncated: false),
      stdout: "hi\n"
    )

    round_tripped = Marshal.load(Marshal.dump(result))

    assert_equal result, round_tripped
    assert_equal "Integer", round_tripped.value.class_name
  end
end
