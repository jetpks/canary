require "test_helper"

class PoolTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures", __dir__)

  def setup
    @pool = Canary::Pool.new
  end

  def test_minitest_adapter_runs_a_real_suite
    result = @pool.rollout(
      adapter: :minitest,
      submission_path: File.join(FIXTURES, "minitest_submission.rb")
    )

    assert_nil result.error
    assert_equal 2, result.total
    assert_equal 1, result.passed
    assert_equal 1, result.failed
    assert_equal %w[passed failed].sort, result.examples.map { |e| e.status.to_s }.sort
  end

  def test_rspec_adapter_runs_a_real_suite
    result = @pool.rollout(
      adapter: :rspec,
      submission_path: File.join(FIXTURES, "rspec_submission.rb")
    )

    assert_nil result.error
    assert_equal 2, result.total
    assert_equal 1, result.passed
    assert_equal 1, result.failed
  end

  def test_coverage_is_collected_for_the_submission_when_requested
    path = File.join(FIXTURES, "minitest_submission.rb")
    result = @pool.rollout(adapter: :minitest, submission_path: path, coverage: true)

    refute_nil result.coverage
    assert_includes result.coverage.keys, path
    assert result.coverage[path][:lines].compact.sum.positive?
  end

  def test_coverage_is_absent_when_not_requested
    path = File.join(FIXTURES, "minitest_submission.rb")
    result = @pool.rollout(adapter: :minitest, submission_path: path, coverage: false)

    assert_nil result.coverage
  end

  def test_unknown_adapter_raises
    assert_raises(ArgumentError) do
      @pool.rollout(adapter: :junit, submission_path: "whatever.rb")
    end
  end

  def test_rollouts_are_isolated_across_forks
    path = File.join(FIXTURES, "minitest_submission.rb")

    first = @pool.rollout(adapter: :minitest, submission_path: path)
    second = @pool.rollout(adapter: :minitest, submission_path: path)

    assert_equal first.total, second.total
    assert_equal first.passed, second.passed
  end

  def test_eval_code_reports_the_evaluated_values_class_and_inspect
    result = @pool.eval_code(code: "6 * 7")

    assert result.ok?
    assert_equal "Integer", result.value.class_name
    assert_equal "42", result.value.inspect_text
    refute result.value.truncated
  end

  def test_eval_code_captures_stdout_and_stderr
    result = @pool.eval_code(code: "$stdout.puts :out_line; $stderr.puts :err_line")

    assert result.ok?
    assert_match(/out_line/, result.stdout.text)
    refute result.stdout.truncated
    assert_match(/err_line/, result.stderr.text)
    refute result.stderr.truncated
  end

  def test_eval_code_output_under_the_cap_is_not_truncated
    result = @pool.eval_code(code: %(print("a" * 1_048_576); $stderr.print("s")), timeout: 15)

    assert result.ok?
    assert_equal 1_048_576, result.stdout.text.bytesize
    refute result.stdout.truncated
    assert_equal "s", result.stderr.text
    refute result.stderr.truncated
  end

  def test_eval_code_output_over_the_cap_is_truncated_per_stream
    limit = Canary::Pool::EVAL_OUTPUT_LIMIT
    result = @pool.eval_code(code: %(print("x" * #{limit + 1}); $stderr.print("e")), timeout: 15)

    assert result.ok?
    assert_equal limit, result.stdout.text.bytesize
    assert result.stdout.truncated
    assert_equal "e", result.stderr.text
    refute result.stderr.truncated
  end

  def test_eval_code_reports_a_raised_standard_error_as_outcome_raised
    result = @pool.eval_code(code: "raise ArgumentError, 'boom from eval'")

    assert result.raised?
    assert_nil result.value
    assert_equal "ArgumentError", result.exception.class_name
    assert_match(/boom from eval/, result.exception.message)
  end

  def test_eval_code_backtrace_never_names_this_files_real_path
    result = @pool.eval_code(code: "begin; raise 'boom'; rescue => e; e.backtrace.first; end")

    assert result.ok?
    assert_match(/\(eval\)/, result.value.inspect_text)
    refute_match(/pool\.rb/, result.value.inspect_text)
  end

  def test_eval_code_bounds_a_huge_inspect_and_surfaces_truncation
    result = @pool.eval_code(code: ":x.to_s * 10_000_000")

    assert result.ok?
    assert result.value.truncated
    assert_operator result.value.inspect_text.bytesize, :<, 10_000_000
  end

  def test_eval_code_is_stateless_across_calls
    first = @pool.eval_code(code: "$canary_eval_probe ||= 0; $canary_eval_probe += 1")
    second = @pool.eval_code(code: "$canary_eval_probe ||= 0; $canary_eval_probe += 1")

    assert_equal "1", first.value.inspect_text
    assert_equal "1", second.value.inspect_text
  end
end
