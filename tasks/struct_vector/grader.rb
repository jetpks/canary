class VectorGraderTest < Minitest::Test
  def test_adds_two_vectors_componentwise
    result = Vector.new(x: 1, y: 2) + Vector.new(x: 3, y: 4)
    assert_equal Vector.new(x: 4, y: 6), result
  end

  def test_addition_does_not_mutate_either_operand
    a = Vector.new(x: 1, y: 2)
    b = Vector.new(x: 3, y: 4)
    _ = a + b
    assert_equal Vector.new(x: 1, y: 2), a
    assert_equal Vector.new(x: 3, y: 4), b
  end

  def test_struct_equality_is_value_based_not_identity
    assert_equal Vector.new(x: 1, y: 2), Vector.new(x: 1, y: 2)
    refute_same Vector.new(x: 1, y: 2), Vector.new(x: 1, y: 2)
  end

  def test_to_h_reflects_members
    assert_equal({ x: 1, y: 2 }, Vector.new(x: 1, y: 2).to_h)
  end
end
