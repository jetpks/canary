class StockCountGraderTest < Minitest::Test
  def test_subtracting_another_stock_count_returns_a_float
    result = StockCount.new(10) - StockCount.new(3)
    assert_kind_of Float, result
    assert_equal 7.0, result
  end

  def test_subtracting_a_rational_returns_a_float_not_a_rational
    result = StockCount.new(10) - Rational(7, 2)
    assert_kind_of Float, result
  end

  def test_subtracting_a_rational_computes_self_minus_other_not_the_reverse
    result = StockCount.new(10) - Rational(7, 2)
    assert_equal 6.5, result
  end

  def test_count_reader_returns_the_constructor_argument_unchanged
    assert_equal 10, StockCount.new(10).count
  end

  def test_equality_compares_by_count_not_identity
    assert_equal StockCount.new(4), StockCount.new(4)
    refute_equal StockCount.new(4), StockCount.new(5)
  end
end
