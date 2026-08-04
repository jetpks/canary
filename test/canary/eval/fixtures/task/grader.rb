class AdderGraderTest < Minitest::Test
  def test_adds_two_positive_numbers
    assert_equal 4, Adder.call(2, 2)
  end

  def test_adds_a_negative_number
    assert_equal 0, Adder.call(5, -5)
  end
end
