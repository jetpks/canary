class StepsGraderTest < Minitest::Test
  def test_each_with_a_block_yields_the_countdown_in_order
    seen = []
    Steps.new(3).each { |n| seen << n }
    assert_equal [3, 2, 1], seen
  end

  def test_each_with_a_block_returns_the_steps_instance_itself
    steps = Steps.new(3)
    assert_same steps, (steps.each { |n| n })
  end

  def test_each_without_a_block_can_be_driven_one_value_at_a_time
    enum = Steps.new(3).each
    assert_equal 3, enum.next
    assert_equal 2, enum.next
    assert_equal 1, enum.next
    assert_raises(StopIteration) { enum.next }
  end

  def test_each_without_a_block_supports_with_index
    pairs = Steps.new(3).each.with_index.to_a
    assert_equal [[3, 0], [2, 1], [1, 2]], pairs
  end

  def test_each_without_a_block_supports_to_a
    assert_equal [3, 2, 1], Steps.new(3).each.to_a
  end
end
