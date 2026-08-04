class CoordinateGraderTest < Minitest::Test
  def test_exposes_row_and_col_unchanged
    coordinate = Coordinate.new(3, 4)
    assert_equal 3, coordinate.row
    assert_equal 4, coordinate.col
  end

  def test_destructures_via_multiple_assignment
    row, col = Coordinate.new(3, 4)
    assert_equal 3, row
    assert_equal 4, col
  end

  def test_splats_into_a_method_call
    assert_equal [3, 4], splat_two(Coordinate.new(3, 4))
  end

  def test_splats_into_an_array_literal
    assert_equal [0, 3, 4], [0, *Coordinate.new(3, 4)]
  end

  def test_converts_via_kernel_array
    assert_equal [3, 4], Array(Coordinate.new(3, 4))
  end

  private

  def splat_two(coordinate)
    two(*coordinate)
  end

  def two(a, b)
    [a, b]
  end
end
