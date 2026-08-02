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

  def test_first_n_takes_from_index_order
    assert_equal %w[one three], build.first(2)
  end

  def test_min_by_derives_from_each
    assert_equal "one", build.min_by { |v| v.length }
  end

  def test_reduce_combines_via_a_symbol
    arr = SparseArray.new
    arr[10] = 4
    arr[2] = 6
    assert_equal 10, arr.reduce(:+)
  end
end
