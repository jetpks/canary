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
end
