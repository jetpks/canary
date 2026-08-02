class TallyGraderTest < Minitest::Test
  def test_returns_a_hash_with_only_the_even_and_odd_keys
    result = Tally.group_by_parity([1, 2, 3, 4, 5, 6])
    assert_equal %i[even odd], result.keys.sort
  end

  def test_groups_even_numbers_correctly
    result = Tally.group_by_parity([1, 2, 3, 4, 5, 6])
    assert_equal [2, 4, 6], result[:even]
  end

  def test_groups_odd_numbers_correctly
    result = Tally.group_by_parity([1, 2, 3, 4, 5, 6])
    assert_equal [1, 3, 5], result[:odd]
  end

  def test_the_even_and_odd_arrays_are_not_the_same_object
    result = Tally.group_by_parity([1, 2, 3, 4, 5, 6])
    refute_same result[:even], result[:odd]
  end
end
