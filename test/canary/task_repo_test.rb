require "test_helper"

# Proves the v0 corpus under tasks/** both ways through the real
# Canary::Pool#rollout_task: every reference solution passes its grader, and
# every deliberately-broken solution fails it - on real per-example results,
# not a boolean.
class TaskRepoTest < Minitest::Test
  def setup
    @pool = Canary::Pool.new
    @entries = Canary::TaskRepo.all
  end

  def test_the_corpus_meets_the_shape_floor
    assert_operator @entries.size, :>=, 8
    assert_operator @entries.map(&:category).uniq.size, :>=, 6
    assert_includes @entries.map(&:adapter), :rspec
  end

  def test_metaprogramming_open_record_reference_passes_and_broken_fails
    entry = entry("metaprogramming_open_record")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    broken = @pool.rollout_task(task: entry.broken)
    assert_result broken, total: 4, passed: 3, failed: 1
    assert_failed broken, "OpenRecordGraderTest#test_responds_to_known_and_settable_attributes"
  end

  def test_block_safe_caller_reference_passes_and_broken_fails
    entry = entry("block_safe_caller")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    broken = @pool.rollout_task(task: entry.broken)
    assert_result broken, total: 4, passed: 3, failed: 1
    assert_failed broken, "SafeCallerGraderTest#test_calls_a_proc_even_with_too_few_arguments_since_procs_never_raise_on_arity"
  end

  def test_enumerable_sparse_array_reference_passes_and_broken_fails
    entry = entry("enumerable_sparse_array")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    broken = @pool.rollout_task(task: entry.broken)
    assert_result broken, total: 4, passed: 3, failed: 1
    assert_failed broken, "SparseArrayGraderTest#test_enumerates_stored_values_in_index_order"
  end

  def test_comparable_money_reference_passes_and_broken_fails
    entry = entry("comparable_money")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 5, passed: 5, failed: 0

    broken = @pool.rollout_task(task: entry.broken)
    assert_equal 5, broken.total
    assert_operator broken.passed, :>, 0
    assert_operator broken.failed, :>, 0
    names = broken.examples.select { |e| e.status == :failed }.map(&:name)
    assert_includes names, "Money comparable protocol orders values that would break under lexical string comparison"
  end

  def test_struct_vector_reference_passes_and_broken_fails
    entry = entry("struct_vector")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    broken = @pool.rollout_task(task: entry.broken)
    assert_result broken, total: 4, passed: 3, failed: 1
    assert_failed broken, "VectorGraderTest#test_addition_does_not_mutate_either_operand"
  end

  def test_exception_retrier_reference_passes_and_broken_fails
    entry = entry("exception_retrier")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    broken = @pool.rollout_task(task: entry.broken)
    assert_result broken, total: 4, passed: 3, failed: 1
    assert_failed broken, "RetrierGraderTest#test_does_not_retry_a_permanent_error"
  end

  def test_string_attr_parser_reference_passes_and_broken_fails
    entry = entry("string_attr_parser")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    broken = @pool.rollout_task(task: entry.broken)
    assert_result broken, total: 4, passed: 3, failed: 1
    assert_failed broken, "AttrParserGraderTest#test_parses_multiple_pairs_without_greedily_crossing_quotes"
  end

  def test_refinement_hollow_check_reference_passes_and_broken_fails
    entry = entry("refinement_hollow_check")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    broken = @pool.rollout_task(task: entry.broken)
    assert_result broken, total: 4, passed: 3, failed: 1
    assert_failed broken, "HollowCheckerGraderTest#test_the_refinement_does_not_leak_outside_its_using_scope"
  end

  def test_block_memoizer_reference_passes_and_broken_fails
    entry = entry("block_memoizer")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    broken = @pool.rollout_task(task: entry.broken)
    assert_result broken, total: 4, passed: 3, failed: 1
    names = broken.examples.select { |e| e.status == :failed }.map(&:name)
    assert_includes names, "Memoizer closures over mutable state caches a falsy result instead of recomputing it"
  end

  def test_every_task_in_the_corpus_is_proven_both_ways
    @entries.each do |entry|
      reference = @pool.rollout_task(task: entry.reference)
      assert reference.success?, "#{entry.name}: expected reference solution to pass (#{reference.error || reference.examples.map { |e| [e.name, e.status] }})"

      broken = @pool.rollout_task(task: entry.broken)
      refute broken.success?, "#{entry.name}: expected broken solution to fail, not pass vacuously"
      assert_operator broken.failed, :>, 0, "#{entry.name}: broken solution reported no failing examples"
    end
  end

  # BRIEF §6/AC7: prove, against the real pool, that coverage attributed to
  # a task's solution contains only the solution - not the grader, not the
  # broken sibling, not the framework. Picked struct_vector arbitrarily; any
  # task would do since the convention is in the shared adapters, not per-task.
  def test_coverage_attribution_is_scoped_to_the_solution_alone
    entry = entry("struct_vector")

    result = @pool.rollout_task(task: entry.reference)

    assert_equal [entry.reference.solution_path], result.coverage.keys
  end

  private

  def entry(name)
    @entries.find { |e| e.name == name } || raise("no such task: #{name.inspect}")
  end

  def assert_result(result, total:, passed:, failed:)
    assert_nil result.error, "expected no error, got #{result.error.inspect}"
    assert_equal total, result.total, "total mismatch: #{result.examples.map { |e| [e.name, e.status] }}"
    assert_equal passed, result.passed, "passed mismatch: #{result.examples.map { |e| [e.name, e.status] }}"
    assert_equal failed, result.failed, "failed mismatch: #{result.examples.map { |e| [e.name, e.status] }}"
  end

  def assert_failed(result, example_name)
    failing = result.examples.select { |e| e.status == :failed }.map(&:name)
    assert_includes failing, example_name
  end
end
