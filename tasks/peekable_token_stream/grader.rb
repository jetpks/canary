class TokenStreamGraderTest < Minitest::Test
  def test_next_returns_tokens_in_order
    stream = TokenStream.new([:a, :b, :c])
    assert_equal :a, stream.next
    assert_equal :b, stream.next
    assert_equal :c, stream.next
  end

  def test_next_raises_stop_iteration_once_exhausted
    stream = TokenStream.new([:a])
    stream.next
    assert_raises(StopIteration) { stream.next }
  end

  def test_peek_returns_the_same_value_repeatedly_without_consuming
    stream = TokenStream.new([:a, :b])
    assert_equal :a, stream.peek
    assert_equal :a, stream.peek
    assert_equal :a, stream.next
    assert_equal :b, stream.next
  end

  def test_peek_raises_stop_iteration_once_exhausted
    stream = TokenStream.new([:a])
    stream.next
    assert_raises(StopIteration) { stream.peek }
  end

  def test_rewind_resets_the_stream_to_the_beginning
    stream = TokenStream.new([:a, :b])
    stream.next
    stream.next
    stream.rewind
    assert_equal :a, stream.next
  end
end
