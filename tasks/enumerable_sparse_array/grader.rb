class SparseArrayGraderTest < Minitest::Test
  def build
    arr = SparseArray.new
    arr[5] = "five"
    arr[1] = "one"
    arr[3] = "three"
    arr
  end

  def test_enumerates_stored_values_in_index_order
    assert_equal %w[one three five], build.to_a
  end

  def test_sum_of_numeric_values
    arr = SparseArray.new
    arr[10] = 4
    arr[2] = 6
    assert_equal 10, arr.sum
  end

  def test_select_returns_an_enumerable_derived_array
    assert_equal(["three"], build.select { |v| v.start_with?("t") })
  end

  def test_count_reflects_only_stored_entries
    assert_equal 3, build.count
  end
end
