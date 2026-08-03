class FractionGraderTest < Minitest::Test
  def test_adds_two_fractions
    assert_equal Fraction.new(5, 6), Fraction.new(1, 2) + Fraction.new(1, 3)
  end

  def test_adds_a_plain_integer
    assert_equal Fraction.new(3, 2), Fraction.new(1, 2) + 1
  end

  def test_adds_when_the_integer_comes_first
    assert_equal Fraction.new(3, 2), 1 + Fraction.new(1, 2)
  end

  def test_adds_when_the_integer_comes_first_with_a_different_value
    assert_equal Fraction.new(9, 4), 2 + Fraction.new(1, 4)
  end

  def test_exposes_numerator_and_denominator_unchanged
    fraction = Fraction.new(3, 4)
    assert_equal 3, fraction.numerator
    assert_equal 4, fraction.denominator
  end

  def test_equality_does_not_require_identity
    assert_equal Fraction.new(1, 2), Fraction.new(1, 2)
    refute_equal Fraction.new(1, 2), Fraction.new(1, 3)
  end
end
