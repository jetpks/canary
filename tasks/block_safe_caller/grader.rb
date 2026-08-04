class SafeCallerGraderTest < Minitest::Test
  def test_calls_a_lambda_with_a_matching_argument_count
    add = ->(a, b) { a + b }
    assert_equal 5, SafeCaller.call(add, 2, 3, default: :nope)
  end

  def test_falls_back_to_the_default_for_a_lambda_arity_mismatch
    add = ->(a, b) { a + b }
    assert_equal :nope, SafeCaller.call(add, 2, default: :nope)
  end

  def test_falls_back_to_the_default_for_a_lambda_given_too_many_arguments
    add = ->(a, b) { a + b }
    assert_equal :nope, SafeCaller.call(add, 1, 2, 3, default: :nope)
  end

  def test_never_invokes_the_callable_when_falling_back_to_the_default
    calls = 0
    add = ->(a, b) { calls += 1; a + b }
    result = SafeCaller.call(add, 1, default: :nope)
    assert_equal :nope, result
    assert_equal 0, calls
  end

  def test_calls_a_proc_even_with_too_few_arguments_since_procs_never_raise_on_arity
    add = proc { |a, b| [a, b] }
    assert_equal [2, nil], SafeCaller.call(add, 2, default: :nope)
  end

  def test_calls_a_proc_even_with_too_many_arguments_since_procs_never_raise_on_arity
    add = proc { |a, b| [a, b] }
    assert_equal [1, 2], SafeCaller.call(add, 1, 2, 3, default: :nope)
  end

  def test_calls_a_proc_with_a_matching_argument_count
    add = proc { |a, b| a + b }
    assert_equal 7, SafeCaller.call(add, 3, 4, default: :nope)
  end
end
