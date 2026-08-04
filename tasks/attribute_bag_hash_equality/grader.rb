class AttributesGraderTest < Minitest::Test
  def test_equals_a_hash_with_the_same_pairs
    assert Attributes.new(a: 1, b: 2) == { a: 1, b: 2 }
  end

  def test_does_not_equal_a_hash_with_different_pairs
    refute Attributes.new(a: 1) == { a: 2 }
  end

  def test_does_not_raise_and_returns_false_for_a_string
    refute Attributes.new(a: 1) == "a string"
  end

  def test_does_not_raise_and_returns_false_for_a_plain_object_with_no_to_h
    refute Attributes.new(a: 1) == Object.new
  end

  def test_an_empty_attributes_is_not_equal_to_nil
    refute_operator Attributes.new, :==, nil
  end

  def test_to_h_reflects_constructor_values
    assert_equal({ a: 1, b: 2 }, Attributes.new(a: 1, b: 2).to_h)
  end
end
