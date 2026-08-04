require_relative "../test_helper"
require "coverage"

# Proves, by running real code in real forked processes rather than by
# assertion-free narration, the load-bearing invariant behind the pool:
# Ruby compiles Coverage's hooks into the InstructionSequence at PARSE time.
# Only code parsed after Coverage.start/.setup is instrumented; executing
# already-parsed code after Coverage.start does not retroactively
# instrument it.
class CoverageOrderingTest < Minitest::Test
  TARGET = File.expand_path("fixtures/coverage_target.rb", __dir__)

  def test_parsing_before_coverage_start_yields_no_coverage_for_that_file
    reader, writer = IO.pipe

    pid = fork do
      reader.close
      require TARGET # parsed (and executed) BEFORE Coverage exists
      Coverage.start(lines: true)
      CoverageTarget.call # executing already-parsed code after start...
      result = Coverage.result
      Marshal.dump(result, writer)
      writer.close
      exit!(0)
    end
    writer.close
    result = Marshal.load(reader.read)
    reader.close
    Process.wait(pid)

    # ...does not retroactively instrument it: no entry for TARGET at all.
    refute_includes result.keys, TARGET,
      "expected no coverage entry for a file parsed before Coverage.start"
  end

  def test_parsing_after_coverage_start_yields_coverage_for_that_file
    reader, writer = IO.pipe

    pid = fork do
      reader.close
      Coverage.start(lines: true)
      load TARGET # parsed AFTER Coverage.start
      CoverageTarget.call
      result = Coverage.result
      Marshal.dump(result, writer)
      writer.close
      exit!(0)
    end
    writer.close
    result = Marshal.load(reader.read)
    reader.close
    Process.wait(pid)

    assert_includes result.keys, TARGET
    lines = result[TARGET][:lines]
    assert lines.compact.sum.positive?,
      "expected at least one executed, instrumented line in #{TARGET}"
  end

  # BRIEF §4.4: a rollout's Coverage.result contains the submission and
  # nothing else. Proven here against the real pool, not against adapters in
  # isolation, since the invariant is about what a fork actually compiles.
  def test_rspec_rollout_coverage_contains_only_the_submission
    pool = Canary::Pool.new(adapters: [:rspec])
    path = File.expand_path("fixtures/rspec_submission.rb", __dir__)

    result = pool.rollout(adapter: :rspec, submission_path: path)

    assert_equal [path], result.coverage.keys
  end

  # A fix that only preloaded the "eq" matcher's own lazy require would pass
  # the test above without closing the general case. This fixture uses a
  # different matcher (include) and a mock, neither preloaded by name.
  def test_rspec_rollout_coverage_excludes_other_matchers_and_mocks
    pool = Canary::Pool.new(adapters: [:rspec])
    path = File.expand_path("fixtures/rspec_other_matchers_submission.rb", __dir__)

    result = pool.rollout(adapter: :rspec, submission_path: path)

    assert_equal [path], result.coverage.keys
  end

  def test_minitest_rollout_coverage_contains_only_the_submission
    pool = Canary::Pool.new(adapters: [:minitest])
    path = File.expand_path("fixtures/minitest_submission.rb", __dir__)

    result = pool.rollout(adapter: :minitest, submission_path: path)

    assert_equal [path], result.coverage.keys
  end

  # Minitest::Test.make_my_diffs_pretty! lazily requires "pp"; a submission
  # that calls it must not leak pp/prettyprint into its own coverage either.
  def test_minitest_rollout_coverage_excludes_pretty_diff_lazy_require
    pool = Canary::Pool.new(adapters: [:minitest])
    path = File.expand_path("fixtures/minitest_pretty_diff_submission.rb", __dir__)

    result = pool.rollout(adapter: :minitest, submission_path: path)

    assert_equal [path], result.coverage.keys
  end

  # §4.4's invariant re-opens for a two-file task, because there are now TWO
  # files to order against Coverage.start (BRIEF §3): the grader is loaded
  # first (registering examples but not running them), then Coverage.start,
  # then the solution - so coverage attributed to the task contains the
  # solution's path and nothing else: not the grader, not the framework.
  def test_minitest_task_rollout_coverage_contains_only_the_solution
    pool = Canary::Pool.new(adapters: [:minitest])
    dir = File.expand_path("task_fixtures/minitest_task", __dir__)
    task = Canary::Task.new(
      solution_path: File.join(dir, "solution.rb"),
      test_path: File.join(dir, "grader.rb"),
      adapter: :minitest
    )

    result = pool.rollout_task(task: task)

    assert_equal [task.solution_path], result.coverage.keys
  end

  def test_rspec_task_rollout_coverage_contains_only_the_solution
    pool = Canary::Pool.new(adapters: [:rspec])
    dir = File.expand_path("task_fixtures/rspec_task", __dir__)
    task = Canary::Task.new(
      solution_path: File.join(dir, "solution.rb"),
      test_path: File.join(dir, "grader.rb"),
      adapter: :rspec
    )

    result = pool.rollout_task(task: task)

    assert_equal [task.solution_path], result.coverage.keys
  end
end
