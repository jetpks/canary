class TallyGraderTest < Minitest::Test
  def test_groups_items_by_the_blocks_return_value
    result = Tally.group_by([1, 2, 3, 4, 5, 6]) { |n| n.even? ? :even : :odd }
    assert_equal [1, 3, 5], result[:odd]
    assert_equal [2, 4, 6], result[:even]
  end

  def test_two_different_keys_arrays_are_independent_objects
    result = Tally.group_by([1, 2, 3, 4, 5, 6]) { |n| n.even? ? :even : :odd }
    refute_same result[:even], result[:odd]
  end

  def test_mutating_one_keys_array_never_affects_another_keys_array
    result = Tally.group_by(%w[a bb ccc dddd ee]) { |s| s.length }
    result[1] << "mutated"
    assert_equal %w[bb ee], result[2]
  end

  def test_returns_only_the_keys_that_actually_occurred
    result = Tally.group_by([1, 3, 5]) { |n| n.even? ? :even : :odd }
    assert_equal [:odd], result.keys
  end
end
