require "minitest"

# A gem-shaped submission: a small Stack implementation plus a realistic
# ~20-example test suite, used to measure per-rollout cost against
# something bigger than a toy.
class Stack
  Empty = Class.new(StandardError)

  def initialize
    @items = []
  end

  def push(item)
    @items.push(item)
    self
  end

  def pop
    raise Empty, "stack is empty" if @items.empty?

    @items.pop
  end

  def peek
    raise Empty, "stack is empty" if @items.empty?

    @items.last
  end

  def empty?
    @items.empty?
  end

  def size
    @items.size
  end

  def to_a
    @items.dup
  end
end

class BenchMinitestSubmission < Minitest::Test
  def setup
    @stack = Stack.new
  end

  def test_new_stack_is_empty
    assert @stack.empty?
  end

  def test_new_stack_has_zero_size
    assert_equal 0, @stack.size
  end

  def test_push_returns_self
    assert_same @stack, @stack.push(1)
  end

  def test_push_increases_size
    @stack.push(1)
    assert_equal 1, @stack.size
  end

  def test_push_multiple_increases_size
    @stack.push(1).push(2).push(3)
    assert_equal 3, @stack.size
  end

  def test_push_makes_stack_non_empty
    @stack.push(1)
    refute @stack.empty?
  end

  def test_pop_returns_last_pushed
    @stack.push(1).push(2)
    assert_equal 2, @stack.pop
  end

  def test_pop_removes_item
    @stack.push(1).push(2)
    @stack.pop
    assert_equal 1, @stack.size
  end

  def test_pop_order_is_lifo
    @stack.push(1).push(2).push(3)
    assert_equal [3, 2, 1], [@stack.pop, @stack.pop, @stack.pop]
  end

  def test_pop_on_empty_raises
    assert_raises(Stack::Empty) { @stack.pop }
  end

  def test_peek_returns_last_pushed
    @stack.push(1).push(2)
    assert_equal 2, @stack.peek
  end

  def test_peek_does_not_remove_item
    @stack.push(1).push(2)
    @stack.peek
    assert_equal 2, @stack.size
  end

  def test_peek_on_empty_raises
    assert_raises(Stack::Empty) { @stack.peek }
  end

  def test_to_a_returns_array
    @stack.push(1).push(2)
    assert_equal [1, 2], @stack.to_a
  end

  def test_to_a_does_not_mutate_stack
    @stack.push(1)
    @stack.to_a << 2
    assert_equal 1, @stack.size
  end

  def test_size_after_push_and_pop
    @stack.push(1).push(2)
    @stack.pop
    assert_equal 1, @stack.size
  end

  def test_empty_after_push_and_pop
    @stack.push(1)
    @stack.pop
    assert @stack.empty?
  end

  def test_push_accepts_nil
    @stack.push(nil)
    assert_nil @stack.peek
  end

  def test_push_accepts_various_types
    @stack.push(1).push("two").push(:three).push([4])
    assert_equal [4], @stack.pop
    assert_equal :three, @stack.pop
    assert_equal "two", @stack.pop
    assert_equal 1, @stack.pop
  end

  def test_many_pushes_and_pops_stay_consistent
    100.times { |i| @stack.push(i) }
    100.times { |i| assert_equal 99 - i, @stack.pop }
    assert @stack.empty?
  end

  def test_empty_error_message
    error = assert_raises(Stack::Empty) { @stack.pop }
    assert_equal "stack is empty", error.message
  end
end
