class InvokerGraderTest < Minitest::Test
  def test_forwards_positional_arguments_only
    add = ->(a, b) { a + b }
    assert_equal 5, Invoker.call(add, 2, 3)
  end

  def test_forwards_the_default_keyword_argument_when_none_is_given
    greet = ->(name, greeting: "Hello") { "#{greeting}, #{name}!" }
    assert_equal "Hello, Ada!", Invoker.call(greet, "Ada")
  end

  def test_forwards_an_explicit_keyword_argument
    greet = ->(name, greeting: "Hello") { "#{greeting}, #{name}!" }
    assert_equal "Hi, Ada!", Invoker.call(greet, "Ada", greeting: "Hi")
  end

  def test_forwards_the_block_through_to_the_target
    collected = []
    tap_value = ->(value, &blk) { blk&.call(value); value }

    result = Invoker.call(tap_value, 5) { |v| collected << v }

    assert_equal 5, result
    assert_equal [5], collected
  end
end
