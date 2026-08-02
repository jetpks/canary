require "test_helper"
require "tmpdir"

# An executable catalogue of grader-tampering attacks against today's
# Pool#rollout(adapter:, submission_path:). Every fixture under
# tamper_fixtures/ is driven through a real Pool - a real fork, a real
# adapter, a real Marshal round-trip - never loaded directly.
#
# DEFENDED vectors get a real assertion: a regression guard that must keep
# passing. SUCCEEDS vectors get a `skip` naming the vector and what it
# violates, built from the actual RolloutResult the attack produced - the
# rollout still runs for real before the skip fires, so this stays an
# executable catalogue rather than narration. The hardening iteration turns
# skips into assertions as each vector is closed.
class TamperTest < Minitest::Test
  FIXTURES = File.expand_path("tamper_fixtures", __dir__)

  def setup
    @pool = Canary::Pool.new(adapters: %i[minitest rspec])
  end

  # --- redefining the assertion library ---

  def test_redefining_assert_forges_a_pass
    result = rollout(:minitest, "redefine_assert_submission.rb")
    skip "redefine_assert_submission.rb: reopening Minitest::Assertions#assert as a " \
         "no-op forges passed:#{result.passed}/failed:#{result.failed} for a test that " \
         "actually fails - violates: reported pass/fail must reflect what the " \
         "submission's own assertions actually did"
  end

  def test_method_missing_can_stand_in_for_a_redefined_assertion
    result = rollout(:minitest, "method_missing_assert_submission.rb")
    skip "method_missing_assert_submission.rb: undef_method'ing assert_equal and " \
         "catching assert_* via method_missing forges passed:#{result.passed}/" \
         "failed:#{result.failed} - violates: the same guarantee as a direct " \
         "reopen, via a different mechanism the harness also can't see"
  end

  def test_rspec_redefining_the_expectation_target_forges_a_pass
    result = rollout(:rspec, "rspec_redefine_expectation_submission.rb")
    skip "rspec_redefine_expectation_submission.rb: reopening " \
         "RSpec::Expectations::ExpectationTarget#to forges passed:#{result.passed}/" \
         "failed:#{result.failed} for `expect(4).to eq(5)` - violates: reported " \
         "pass/fail must reflect what the submission's own expectations actually did"
  end

  # --- forging RolloutResult before it is marshalled ---

  def test_reopening_rollout_result_new_ignores_the_real_counts
    result = rollout(:minitest, "forge_rollout_result_new_submission.rb")
    skip "forge_rollout_result_new_submission.rb: reopening " \
         "Canary::RolloutResult.new to discard its kwargs forges passed:" \
         "#{result.passed}/failed:#{result.failed}/total:#{result.total} regardless " \
         "of what MinitestAdapter#run actually computed - violates: the parent must " \
         "trust only values it computed itself, not values shaped by the submission"
  end

  def test_rspec_reopening_rollout_result_new_is_adapter_independent
    result = rollout(:rspec, "rspec_forge_rollout_result_submission.rb")
    skip "rspec_forge_rollout_result_submission.rb: the same Canary::RolloutResult.new " \
         "reopen used under minitest forges passed:#{result.passed}/failed:" \
         "#{result.failed} under rspec too (passed=#{result.total}) - violates: the " \
         "forgery lives in run_in_child, above both adapters, so it is not adapter-specific"
  end

  # --- method_missing / const_missing interception ---

  def test_const_missing_scoped_to_canary_does_not_reach_pool_or_the_adapter
    result = rollout(:minitest, "const_missing_forge_result_submission.rb")

    assert result.crash?, "expected the missing constant to crash the child, not forge a result"
    refute_equal 999, result.passed
  end

  def test_const_missing_hooked_on_object_reaches_every_reference_site
    result = rollout(:minitest, "const_missing_object_forge_result_submission.rb")
    skip "const_missing_object_forge_result_submission.rb: hooking const_missing on " \
         "Object (a real ancestor of Canary::Pool and " \
         "Canary::Adapters::MinitestAdapter, unlike Canary itself) forges passed:" \
         "#{result.passed}/failed:#{result.failed}/total:#{result.total} - violates: " \
         "the parent must trust only values it computed itself"
  end

  # --- vacuous suites ---

  def test_an_empty_suite_passes_vacuously
    result = rollout(:minitest, "empty_suite_submission.rb")
    skip "empty_suite_submission.rb: a Minitest::Test subclass with zero test_ " \
         "methods reports total:#{result.total}/failed:#{result.failed}, and " \
         "RolloutResult#success? is #{result.success?} - violates: a submission " \
         "that runs nothing must not be indistinguishable from one that passed everything"
  end

  def test_rspec_an_empty_describe_passes_vacuously
    result = rollout(:rspec, "rspec_empty_suite_submission.rb")
    skip "rspec_empty_suite_submission.rb: a describe block with zero examples " \
         "reports total:#{result.total}/failed:#{result.failed}, success?:" \
         "#{result.success?} - violates: the same guarantee, rspec flavor"
  end

  def test_reopening_minitest_test_directly_hides_tests_from_the_runnables_diff
    result = rollout(:minitest, "reopen_minitest_test_submission.rb")
    skip "reopen_minitest_test_submission.rb: adding a failing test_ method by " \
         "reopening Minitest::Test itself (already a registered Runnable before any " \
         "submission loads) rather than subclassing it reports total:#{result.total} " \
         "- violates: a real, failing test must not be silently excluded from the run"
  end

  # --- exiting cleanly before assertions run ---

  def test_exiting_before_assertions_run_is_reported_as_a_crash_not_a_pass
    result = rollout(:minitest, "exit_before_assertions_submission.rb")

    assert result.crash?
    refute result.success?
  end

  # --- writing files the harness may later read ---

  def test_writing_files_from_the_sandbox_is_invisible_to_the_reported_result
    proof_path = File.join(Dir.tmpdir, "canary-tamper-write-proof-#{Process.pid}")
    ENV["CANARY_TAMPER_WRITE_PATH"] = proof_path
    result = rollout(:minitest, "writes_file_submission.rb")
    wrote = File.exist?(proof_path)

    skip "writes_file_submission.rb: the forked child shares the real filesystem " \
         "(fork isolates memory, not disk) - it wrote #{proof_path.inspect} " \
         "(exists?:#{wrote}) with RolloutResult reporting a clean outcome:" \
         "#{result.outcome} and no mention of the write - violates: the harness has " \
         "no visibility into filesystem side effects a submission causes"
  ensure
    ENV.delete("CANARY_TAMPER_WRITE_PATH")
    File.delete(proof_path) if proof_path && File.exist?(proof_path)
  end

  def test_rspec_writing_files_from_the_sandbox_is_invisible_to_the_reported_result
    proof_path = File.join(Dir.tmpdir, "canary-tamper-write-proof-rspec-#{Process.pid}")
    ENV["CANARY_TAMPER_WRITE_PATH"] = proof_path
    result = rollout(:rspec, "rspec_writes_file_submission.rb")
    wrote = File.exist?(proof_path)

    skip "rspec_writes_file_submission.rb: parity check with " \
         "writes_file_submission.rb - it wrote #{proof_path.inspect} (exists?:" \
         "#{wrote}) with RolloutResult reporting outcome:#{result.outcome} and no " \
         "mention of the write - violates: the same filesystem-visibility guarantee, rspec flavor"
  ensure
    ENV.delete("CANARY_TAMPER_WRITE_PATH")
    File.delete(proof_path) if proof_path && File.exist?(proof_path)
  end

  # --- and the vectors nobody listed ---

  def test_pipe_hijack_wins_the_race_against_the_real_result
    result = rollout(:minitest, "pipe_hijack_submission.rb")
    skip "pipe_hijack_submission.rb: ObjectSpace.each_object(IO) finds the parent's " \
         "open pipe writer inside the forked child and Marshal.dumps a forged " \
         "payload onto it before MinitestAdapter counts a single example - " \
         "Marshal.load only consumes the first object in the stream, so this forges " \
         "passed:#{result.passed}/failed:#{result.failed}/total:#{result.total} " \
         "without touching RolloutResult, Minitest, or the assertion library at all - " \
         "violates: the wire between child and parent must carry only what the " \
         "parent's own trusted code writes to it"
  end

  def test_record_forge_leaves_a_correct_example_count_but_a_forged_failure_list
    result = rollout(:minitest, "record_forge_submission.rb")
    skip "record_forge_submission.rb: reopening Minitest::Result.from to clear " \
         "failures on every recorded result (touching neither assert nor " \
         "RolloutResult) forges passed:#{result.passed}/failed:#{result.failed} for " \
         "a suite that actually fails - violates: the same guarantee via a third, " \
         "more surgical mechanism"
  end

  def test_coverage_result_called_early_destroys_a_genuine_pass
    result = rollout(:minitest, "coverage_corruption_submission.rb")
    skip "coverage_corruption_submission.rb: calling the bare Coverage.result " \
         "(which stops measurement as a side effect) before run_in_child's own " \
         "later call raises RuntimeError there, which run_in_child rescues into " \
         "outcome::#{result.outcome} (error:#{result.error.inspect}) - turning an " \
         "honestly-passing rollout into a reported failure - violates: the reported " \
         "outcome must reflect the submission's real pass/fail, not incidental " \
         "interference with the pool's own instrumentation"
  end

  private

  def rollout(adapter, fixture_name, timeout: 5)
    @pool.rollout(
      adapter: adapter,
      submission_path: File.join(FIXTURES, fixture_name),
      timeout: timeout
    )
  end
end
