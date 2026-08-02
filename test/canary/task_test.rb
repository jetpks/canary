require "test_helper"
require "tempfile"
require "tmpdir"
require "fileutils"

# Proves the task seam is real: a solution graded by a separate test file
# that the solution does not contain, run end to end through the real
# Canary::Pool - not a rename of the one-file submission shape.
class TaskTest < Minitest::Test
  FIXTURES = File.expand_path("task_fixtures", __dir__)

  def setup
    @pool = Canary::Pool.new
  end

  def test_a_two_file_minitest_task_runs_end_to_end_and_reports_per_example_results
    result = @pool.rollout_task(task: minitest_task)

    assert_nil result.error
    assert_equal 2, result.total
    assert_equal 2, result.passed
    assert_equal 0, result.failed
    assert_equal %w[TaskAdderGraderTest#test_adds_two_positive_numbers
                     TaskAdderGraderTest#test_adds_a_negative_number].sort,
                 result.examples.map(&:name).sort
  end

  def test_a_two_file_rspec_task_runs_end_to_end_and_reports_per_example_results
    result = @pool.rollout_task(task: rspec_task)

    assert_nil result.error
    assert_equal 2, result.total
    assert_equal 2, result.passed
    assert_equal 0, result.failed
  end

  # The strongest available proof that the grader and solution are genuinely
  # separate: run the intact task, then delete the solution file (a real
  # delete, on a scratch copy so the checked-in fixture is untouched) and
  # run the same task again. A grader that secretly contained its own
  # subject would pass vacuously either way.
  def test_deleting_the_solution_file_makes_the_task_fail_not_pass_vacuously
    Dir.mktmpdir do |dir|
      solution_path = File.join(dir, "solution.rb")
      test_path = File.join(dir, "grader.rb")
      FileUtils.cp(File.join(FIXTURES, "minitest_task", "solution.rb"), solution_path)
      FileUtils.cp(File.join(FIXTURES, "minitest_task", "grader.rb"), test_path)
      task = Canary::Task.new(solution_path: solution_path, test_path: test_path, adapter: :minitest)

      baseline = @pool.rollout_task(task: task)
      assert baseline.success?, "expected the intact two-file task to pass"

      File.delete(solution_path)
      result = @pool.rollout_task(task: task)

      refute result.success?, "expected the task to fail, not pass vacuously, once its solution file is gone"
    end
  end

  def test_a_rollout_whose_grader_was_rewritten_is_reported_invalid_not_scored
    dir = File.join(FIXTURES, "tampering")
    template = File.read(File.join(dir, "grader_template.rb"))

    tempfile = Tempfile.new(%w[tampering_grader .rb])
    tempfile.write(template)
    tempfile.close

    task = Canary::Task.new(
      solution_path: File.join(dir, "solution.rb"),
      test_path: tempfile.path,
      adapter: :minitest
    )

    result = @pool.rollout_task(task: task)

    assert result.invalid?
    refute result.success?
    assert_match(/grader/, result.error)
  ensure
    tempfile&.unlink
  end

  private

  def minitest_task
    dir = File.join(FIXTURES, "minitest_task")
    Canary::Task.new(solution_path: File.join(dir, "solution.rb"), test_path: File.join(dir, "grader.rb"), adapter: :minitest)
  end

  def rspec_task
    dir = File.join(FIXTURES, "rspec_task")
    Canary::Task.new(solution_path: File.join(dir, "solution.rb"), test_path: File.join(dir, "grader.rb"), adapter: :rspec)
  end
end
