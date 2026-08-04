class TaskAdderFailingGraderTest < Minitest::Test
  def test_wrong_expectation
    assert_equal 999, TaskAdder.call(2, 2)
  end
end
