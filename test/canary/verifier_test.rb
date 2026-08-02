require "test_helper"

# Proves the staged verifier: tier 0/1 (Prefilter) gates tier 2 (the
# rollout), binary pass/fail is the only score, and structured signals
# (the prefilter Report, per-example results, coverage) come back either way.
class VerifierTest < Minitest::Test
  FIXTURES = File.expand_path("task_fixtures", __dir__)

  # A fake collaborator, not a mock of the class under test - Verifier is
  # what's being tested, Pool is what's injected. Raising instead of merely
  # recording a call makes the early-exit assertion fail loudly if tier 2
  # is ever reached for a rejected submission, rather than relying on
  # inference from the returned result alone.
  class ExplodingPool
    def rollout_task(**)
      raise "tier 2 must not run for a submission the prefilter rejected"
    end
  end

  def setup
    @pool = Canary::Pool.new
    @verifier = Canary::Verifier.new(pool: @pool)
  end

  def test_a_tier0_reject_never_reaches_the_rollout
    verifier = Canary::Verifier.new(pool: ExplodingPool.new)

    result = verifier.call(tier0_reject_task)

    refute result.prefilter_report.syntax_valid
    assert_nil result.rollout_result
    refute result.passed
  end

  def test_a_tier1_reject_never_reaches_the_rollout
    verifier = Canary::Verifier.new(pool: ExplodingPool.new)

    result = verifier.call(tier1_reject_task)

    assert result.prefilter_report.syntax_valid
    refute result.prefilter_report.clean?
    assert_nil result.rollout_result
    refute result.passed
  end

  def test_a_clean_task_reaches_the_rollout_and_reports_signals
    result = @verifier.call(minitest_task)

    assert result.prefilter_report.clean?
    refute_nil result.rollout_result
    assert_equal 2, result.rollout_result.examples.size
    refute_nil result.rollout_result.coverage
    assert result.passed
  end

  def test_a_clean_task_whose_rollout_fails_is_not_passed
    dir = File.join(FIXTURES, "minitest_task")
    task = Canary::Task.new(
      solution_path: File.join(dir, "solution.rb"),
      test_path: File.join(dir, "failing_grader.rb"),
      adapter: :minitest
    )

    result = @verifier.call(task)

    assert result.prefilter_report.clean?
    refute_nil result.rollout_result
    refute result.rollout_result.success?
    refute result.passed
  end

  def test_the_result_carries_no_score_or_reward
    result = @verifier.call(minitest_task)

    refute_respond_to result, :score
    refute_respond_to result, :reward
  end

  private

  def minitest_task
    dir = File.join(FIXTURES, "minitest_task")
    Canary::Task.new(solution_path: File.join(dir, "solution.rb"), test_path: File.join(dir, "grader.rb"), adapter: :minitest)
  end

  def tier0_reject_task
    Canary::Task.new(
      solution_path: File.join(FIXTURES, "tier0_reject", "solution.rb"),
      test_path: File.join(FIXTURES, "minitest_task", "grader.rb"),
      adapter: :minitest
    )
  end

  def tier1_reject_task
    Canary::Task.new(
      solution_path: File.join(FIXTURES, "tier1_reject", "solution.rb"),
      test_path: File.join(FIXTURES, "minitest_task", "grader.rb"),
      adapter: :minitest
    )
  end
end
