class RetrierGraderTest < Minitest::Test
  def test_returns_the_block_value_on_first_success
    result = Retrier.call(max_attempts: 3) { |n| n }
    assert_equal 1, result
  end

  def test_retries_a_transient_error_until_it_succeeds
    calls = 0
    result = Retrier.call(max_attempts: 3) do |n|
      calls += 1
      raise TransientError, "flaky" if n < 3

      "ok on attempt #{n}"
    end
    assert_equal "ok on attempt 3", result
    assert_equal 3, calls
  end

  def test_does_not_retry_a_permanent_error
    calls = 0
    assert_raises(PermanentError) do
      Retrier.call(max_attempts: 5) do
        calls += 1
        raise PermanentError, "nope"
      end
    end
    assert_equal 1, calls
  end

  def test_reraises_after_exhausting_max_attempts
    calls = 0
    assert_raises(TransientError) do
      Retrier.call(max_attempts: 2) do
        calls += 1
        raise TransientError, "still flaky"
      end
    end
    assert_equal 2, calls
  end
end
