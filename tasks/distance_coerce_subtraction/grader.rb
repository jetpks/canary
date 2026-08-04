class DistanceGraderTest < Minitest::Test
  def test_exposes_meters_unchanged
    assert_equal 10, Distance.new(10).meters
  end

  def test_subtracts_two_distances
    assert_equal Distance.new(7), Distance.new(10) - Distance.new(3)
  end

  def test_subtracts_a_plain_integer
    assert_equal Distance.new(7), Distance.new(10) - 3
  end

  def test_subtracts_when_the_integer_comes_first
    assert_equal Distance.new(7), 10 - Distance.new(3)
  end

  def test_operand_order_is_preserved_when_the_integer_comes_first
    assert_equal Distance.new(-7), 3 - Distance.new(10)
  end

  def test_equality_does_not_require_identity
    assert_equal Distance.new(5), Distance.new(5)
    refute_equal Distance.new(5), Distance.new(6)
  end
end
