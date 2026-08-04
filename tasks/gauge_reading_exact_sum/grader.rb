class ReadingGraderTest < Minitest::Test
  def test_exact_returns_a_rational_for_a_simple_case
    reading = Reading.new(2, Rational(1, 4))
    assert_kind_of Rational, reading.exact
    assert_equal Rational(9, 4), reading.exact.to_r
  end

  def test_preserves_a_fraction_whose_binary_expansion_never_terminates
    reading = Reading.new(0, Rational(1, 3))
    assert_equal Rational(1, 3), reading.exact.to_r
  end

  def test_preserves_precision_when_whole_is_too_large_for_a_float_to_hold_the_fraction
    whole = 10**16
    reading = Reading.new(whole, Rational(1, 4))
    assert_equal Rational((whole * 4) + 1, 4), reading.exact.to_r
  end

  def test_whole_and_fraction_readers_return_constructor_arguments_unchanged
    reading = Reading.new(5, Rational(3, 8))
    assert_equal 5, reading.whole
    assert_equal Rational(3, 8), reading.fraction
  end

  def test_equality_compares_by_exact_value_not_identity
    assert_equal Reading.new(1, Rational(1, 2)), Reading.new(1, Rational(1, 2))
    refute_equal Reading.new(1, Rational(1, 2)), Reading.new(1, Rational(1, 3))
  end
end
