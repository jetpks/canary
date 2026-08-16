require "test_helper"
require "tempfile"
require "stringio"
require "rbconfig"

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

  def test_a_descendant_left_running_by_the_submission_times_out_and_is_killed_with_the_group
    pid_file = Tempfile.new("canary-descendant-pid")
    ENV["CANARY_DESCENDANT_PID_PATH"] = pid_file.path
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = @pool.rollout(
      adapter: :minitest,
      submission_path: fixture("leaves_descendant_submission.rb"),
      timeout: 1
    )

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    descendant_pid = Integer(File.read(pid_file.path))

    assert result.timeout?
    assert_operator elapsed, :<, 5, "expected the pool's own timeout to bound the rollout"
    assert_eventually_dead(descendant_pid)
  ensure
    ENV.delete("CANARY_DESCENDANT_PID_PATH")
    pid_file&.close!
  end

  def test_a_truncated_marshal_payload_is_reported_as_a_crash_not_raised
    result = @pool.rollout(
      adapter: :minitest,
      submission_path: fixture("killed_mid_write_submission.rb")
    )

    assert result.crash?
    assert_match(/signal/, result.error)
  end

  def test_an_argument_error_outside_marshal_load_is_reported_as_malformed_not_a_crash
    # This is the one failure mode #marshalled_result can't be driven into by
    # any real wire byte, since it's a defense against a *future* bug in the
    # build_failure callable itself, not a currently-triggerable one - so
    # it's reached directly, via `send`, rather than through the public
    # #rollout. The stub only raises on its first call (the wire-tampered
    # path, for the extra-object case below); its second call (the rescue
    # path this drives into) behaves like the real builder. Marshal.load and
    # #io.eof? - the behavior actually under test - run for real, on a real
    # two-object wire.
    pid = fork { exit!(0) }
    _pid, status = Process.wait2(pid)
    two_objects_on_the_wire = Marshal.dump(:first) + Marshal.dump(:second)

    calls = 0
    build_failure = lambda do |outcome:, error:|
      calls += 1
      raise ArgumentError, "injected: a bug elsewhere in marshalled_result, not Marshal.load" if calls == 1

      Canary::RolloutResult.new(adapter: :minitest, examples: [], passed: 0, failed: 0, total: 0, outcome: outcome, error: error)
    end

    result = @pool.send(:marshalled_result, two_objects_on_the_wire, status, build_failure)

    assert_match(/ArgumentError/, result.error)
    refute_match(/exited with status|terminated by signal/, result.error)
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

  def test_a_non_terminating_eval_times_out_without_hanging_the_parent
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    result = @pool.eval_code(code: "sleep 30", timeout: 1)

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at

    assert result.timeout?
    assert_operator elapsed, :<, 5, "expected the pool's own timeout to bound the eval"
  end

  def test_an_eval_that_exits_is_reported_as_a_crash
    result = @pool.eval_code(code: "exit!")

    assert result.crash?
    assert_match(/exited with status/, result.error)
  end

  def test_requiring_canary_does_not_mutate_warning_experimental_for_the_host
    # A fresh subprocess that does nothing but require the gem - reading the
    # flag inside this process wouldn't prove anything, since test_helper
    # already required canary long before this test method ran.
    output = IO.popen([RbConfig.ruby, "-Ilib", "-e", "require 'canary'; print Warning[:experimental]"], &:read)

    assert_equal "true", output
  end

  def test_a_normal_rollout_does_not_leak_the_io_buffer_experimental_warning
    original_stderr = $stderr
    $stderr = StringIO.new

    result = @pool.rollout(
      adapter: :minitest,
      submission_path: File.expand_path("minitest_submission.rb", FIXTURES)
    )
    captured = $stderr.string
    $stderr = original_stderr

    assert result.ok?
    refute_match(/IO::Buffer/, captured)
  ensure
    $stderr = original_stderr
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

  # A killed process stays visible to Process.kill(0, ...) as a zombie until
  # whichever process it got reparented to (it's no longer our own direct
  # child once its original parent exits) calls wait on it - a real but
  # small OS-level bookkeeping delay, not a live process we're giving the
  # benefit of the doubt. Polls instead of asserting instantaneously so that
  # delay doesn't read as a failure to kill it.
  def assert_eventually_dead(pid, within: 3)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + within
    loop do
      begin
        Process.kill(0, pid)
      rescue Errno::ESRCH
        return
      end
      raise Minitest::Assertion, "expected descendant #{pid} to be dead within #{within}s, but it is still alive" \
        if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

      sleep 0.05
    end
  end
end
