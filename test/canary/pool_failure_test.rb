require "test_helper"

# Proves, with real submissions in real forked children rather than
# assertion-free narration, that Pool#rollout survives every terminal
# behavior of its child and always returns a distinguishable
# Canary::RolloutResult instead of raising into the caller.
class PoolFailureTest < Minitest::Test
  FIXTURES = File.expand_path("fixtures", __dir__)

  def setup
    @pool = Canary::Pool.new(adapters: %i[minitest])
  end

  def test_exit_is_reported_as_a_crash
    result = @pool.rollout(adapter: :minitest, submission_path: fixture("exit_submission.rb"))

    assert result.crash?
    assert_match(/exited with status/, result.error)
  end

  def test_exit_bang_is_reported_as_a_crash
    result = @pool.rollout(adapter: :minitest, submission_path: fixture("exit_bang_submission.rb"))

    assert result.crash?
    assert_match(/exited with status/, result.error)
  end

  def test_a_raised_exception_is_reported_as_an_error_not_a_crash
    result = @pool.rollout(adapter: :minitest, submission_path: fixture("raising_submission.rb"))

    assert result.error?
    refute result.crash?
    assert_match(/boom from submission/, result.error)
  end

  def test_death_by_signal_is_reported_as_a_crash
    result = @pool.rollout(adapter: :minitest, submission_path: fixture("signaled_submission.rb"))

    assert result.crash?
    assert_match(/signal/, result.error)
  end

  def test_a_non_terminating_submission_times_out_without_hanging_the_parent
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = @pool.rollout(
      adapter: :minitest,
      submission_path: fixture("hanging_submission.rb"),
      timeout: 1
    )

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    assert result.timeout?
    assert_operator elapsed, :<, 5, "expected the pool's own timeout to bound the rollout"
  end

  def test_a_normal_rollout_is_still_a_success
    result = @pool.rollout(
      adapter: :minitest,
      submission_path: File.expand_path("minitest_submission.rb", FIXTURES)
    )

    assert result.ok?
    refute result.crash?
    refute result.timeout?
  end

  def test_killed_and_crashed_children_are_reaped_and_leave_no_zombies
    @pool.rollout(adapter: :minitest, submission_path: fixture("hanging_submission.rb"), timeout: 1)
    @pool.rollout(adapter: :minitest, submission_path: fixture("signaled_submission.rb"))
    @pool.rollout(adapter: :minitest, submission_path: fixture("exit_submission.rb"))

    # Every rollout above reaps its own child before returning, so by now
    # this process should have no children left at all - a zombie would
    # still be picked up by a wait on any child.
    assert_raises(Errno::ECHILD) { Process.wait2(-1, Process::WNOHANG) }
  end

  private

  def fixture(name)
    File.join(FIXTURES, name)
  end
end
