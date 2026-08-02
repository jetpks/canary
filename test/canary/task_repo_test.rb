require "test_helper"

# Proves the corpus under tasks/** both ways through the real
# Canary::Pool#rollout_task: every reference solution passes its grader,
# every deliberately-broken solution fails it, and - the AC7 bar - a task's
# broken solutions fail on DIFFERENT examples from each other, not the same
# one twice. Two broken solutions caught by the same assertion have not
# widened the grader.
class TaskRepoTest < Minitest::Test
  def setup
    @pool = Canary::Pool.new
    @entries = Canary::TaskRepo.all
  end

  def test_the_corpus_meets_the_shape_floor
    assert_operator @entries.size, :>=, 13
    assert_operator @entries.map(&:category).uniq.size, :>=, 12
    assert_includes @entries.map(&:adapter), :rspec
  end

  def test_every_task_has_at_least_two_broken_solutions
    @entries.each do |entry|
      assert_operator entry.broken_solutions.size, :>=, 2, "#{entry.name}: needs at least two broken solutions"
    end
  end

  def test_struct_vector_reference_passes_and_broken_solutions_fail_differently
    entry = entry("struct_vector")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    assert_broken_fails_on(entry, "mutates_operands", "VectorGraderTest#test_addition_does_not_mutate_either_operand")
    assert_broken_fails_on(entry, "transposed_addition", "VectorGraderTest#test_adds_two_vectors_componentwise")
  end

  def test_comparable_money_reference_passes_and_broken_solutions_fail_differently
    entry = entry("comparable_money")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 7, passed: 7, failed: 0

    assert_broken_fails_on(entry, "lexical_string_compare", "Money comparable protocol orders values that would break under lexical string comparison")
    assert_broken_fails_on(entry, "reversed_comparison", "Money comparable protocol orders small values correctly")
  end

  def test_block_memoizer_reference_passes_and_broken_solutions_fail_differently
    entry = entry("block_memoizer")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    assert_broken_fails_on(entry, "or_equals_recomputes_falsy", "Memoizer closures over mutable state caches a falsy result instead of recomputing it")
    assert_broken_fails_on(entry, "drops_call_time_args", "Memoizer closures over mutable state passes call-time arguments through to the computation")
  end

  def test_block_safe_caller_reference_passes_and_broken_solutions_fail_differently
    entry = entry("block_safe_caller")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 7, passed: 7, failed: 0

    assert_broken_fails_on(entry, "ignores_lambda_vs_proc", "SafeCallerGraderTest#test_calls_a_proc_even_with_too_few_arguments_since_procs_never_raise_on_arity")
    assert_broken_fails_on(entry, "inverted_arity_check", "SafeCallerGraderTest#test_calls_a_lambda_with_a_matching_argument_count")
  end

  def test_enumerable_sparse_array_reference_passes_and_broken_solutions_fail_differently
    entry = entry("enumerable_sparse_array")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 7, passed: 7, failed: 0

    assert_broken_fails_on(entry, "unsorted_each", "SparseArrayGraderTest#test_enumerates_stored_values_in_index_order")
    assert_broken_fails_on(entry, "swapped_key_value", "SparseArrayGraderTest#test_sum_of_numeric_values")
  end

  def test_exception_retrier_reference_passes_and_broken_solutions_fail_differently
    entry = entry("exception_retrier")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    assert_broken_fails_on(entry, "rescues_standard_error", "RetrierGraderTest#test_does_not_retry_a_permanent_error")
    assert_broken_fails_on(entry, "swallows_after_exhaustion", "RetrierGraderTest#test_reraises_after_exhausting_max_attempts")
  end

  def test_metaprogramming_open_record_reference_passes_and_broken_solutions_fail_differently
    entry = entry("metaprogramming_open_record")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    assert_broken_fails_on(entry, "missing_respond_to_missing", "OpenRecordGraderTest#test_responds_to_known_and_settable_attributes")
    assert_broken_fails_on(entry, "write_path_no_ops", "OpenRecordGraderTest#test_writes_a_new_attribute_dynamically")
  end

  def test_string_attr_parser_reference_passes_and_broken_solutions_fail_differently
    entry = entry("string_attr_parser")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    assert_broken_fails_on(entry, "greedy_value_match", "AttrParserGraderTest#test_parses_multiple_pairs_without_greedily_crossing_quotes")
    assert_broken_fails_on(entry, "excludes_spaces_from_value", "AttrParserGraderTest#test_handles_a_value_containing_spaces")
  end

  def test_shadowed_constant_circle_reference_passes_and_broken_solutions_fail_differently
    entry = entry("shadowed_constant_circle")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    assert_broken_fails_on(entry, "shadowed_constant", "CircleGraderTest#test_area_uses_the_real_value_of_pi_not_the_shadowed_local_constant")
    assert_broken_fails_on(entry, "circumference_missing_diameter_factor", "CircleGraderTest#test_circumference_uses_the_real_value_of_pi_and_the_full_diameter")

    # The distinguishing example: only the shadowing mistake trips the area
    # assertion - the diameter-factor mistake leaves area alone.
    area_failures = broken_result(entry, "circumference_missing_diameter_factor").examples
      .select { |e| e.status == :failed }
      .map(&:name)
    refute_includes area_failures, "CircleGraderTest#test_area_uses_the_real_value_of_pi_not_the_shadowed_local_constant"
  end

  def test_hash_default_proc_tally_reference_passes_and_broken_solutions_fail_differently
    entry = entry("hash_default_proc_tally")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    assert_broken_fails_on(entry, "shared_default_array", "TallyGraderTest#test_two_different_keys_arrays_are_independent_objects")
    assert_broken_fails_on(entry, "swapped_key_and_value", "TallyGraderTest#test_groups_items_by_the_blocks_return_value")

    # The distinguishing example: only the shared-default mistake corrupts
    # independence between two keys' arrays - the swapped key/value mistake
    # still hands back two distinct, independent Array objects, just filled
    # with the wrong content under the wrong keys.
    swapped_failures = broken_result(entry, "swapped_key_and_value").examples
      .select { |e| e.status == :failed }
      .map(&:name)
    refute_includes swapped_failures, "TallyGraderTest#test_two_different_keys_arrays_are_independent_objects"
  end

  def test_eql_hash_distance_point_reference_passes_and_broken_solutions_fail_differently
    entry = entry("eql_hash_distance_point")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 6, passed: 6, failed: 0

    assert_broken_fails_on(entry, "missing_eql_and_hash", "Point comparable + hash contract dedupes equal-valued points with uniq")
    assert_broken_fails_on(entry, "orders_by_x_only", "Point comparable + hash contract sorts a mixed array by distance")

    # The pair is fully disjoint: the Comparable-vs-eql?/hash mistake never
    # trips an ordering assertion, and the ordering mistake never trips a
    # Hash/uniq assertion.
    missing_eql_failures = broken_result(entry, "missing_eql_and_hash").examples.select { |e| e.status == :failed }.map(&:name)
    orders_by_x_failures = broken_result(entry, "orders_by_x_only").examples.select { |e| e.status == :failed }.map(&:name)
    assert_empty missing_eql_failures & orders_by_x_failures
  end

  def test_ensure_return_swallows_exception_reference_passes_and_broken_solutions_fail_differently
    entry = entry("ensure_return_swallows_exception")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 4, passed: 4, failed: 0

    assert_broken_fails_on(entry, "ensure_returns_and_swallows", "TransactionRunnerGraderTest#test_a_failure_still_propagates_past_cleanup")
    assert_broken_fails_on(entry, "cleanup_only_on_success", "TransactionRunnerGraderTest#test_runs_cleanup_even_when_the_block_fails")
  end

  def test_enumerator_lazy_short_circuit_reference_passes_and_broken_solutions_fail_differently
    entry = entry("enumerator_lazy_short_circuit")

    reference = @pool.rollout_task(task: entry.reference)
    assert_result reference, total: 3, passed: 3, failed: 0

    assert_broken_fails_on(entry, "eager_select", "Finder.first_matching stops pulling from the source once it has enough matches")
    assert_broken_fails_on(entry, "small_fixed_lookahead", "Finder.first_matching supports chaining a further filter without having committed to a fixed count ahead of time")
  end

  # Dynamic loop over every entry, catching a task added without a
  # dedicated test above and enforcing the AC7 bar generically: every
  # broken solution fails with at least one example, and no two of a
  # task's broken solutions fail on the identical set of examples.
  #
  # mechanism_free is excluded from the discrimination bar (not from the
  # must-fail check, which test_every_task_carries_a_mechanism_free_broken_
  # solution_that_its_grader_rejects covers below): it exists to prove a
  # different property (a mechanism-ignorant solution can't pass) and is
  # explicitly permitted to fail on the same examples as an existing broken
  # solution.
  def test_every_task_in_the_corpus_is_proven_both_ways_and_discriminates
    @entries.each do |entry|
      reference = @pool.rollout_task(task: entry.reference)
      assert reference.success?, "#{entry.name}: expected reference solution to pass (#{reference.error || reference.examples.map { |e| [e.name, e.status] }})"

      failing_sets = entry.broken_solutions.reject { |b| b.id == "mechanism_free" }.map do |b|
        result = @pool.rollout_task(task: b.task)
        refute result.success?, "#{entry.name}/#{b.id}: expected broken solution to fail, not pass vacuously"
        failing = result.examples.select { |e| e.status == :failed }.map(&:name).sort
        assert_operator failing.size, :>, 0, "#{entry.name}/#{b.id}: broken solution reported no failing examples"
        failing
      end

      failing_sets.combination(2).each do |a, b|
        refute_equal a, b, "#{entry.name}: two broken solutions failed on the identical set of examples"
      end
    end
  end

  # AC3: every surviving task carries broken/mechanism_free.rb (the simplest
  # solution that ignores the task's trap), and its grader rejects it - not
  # a hardcoded list, every entry TaskRepo.all resolves right now.
  def test_every_task_carries_a_mechanism_free_broken_solution_that_its_grader_rejects
    @entries.each do |entry|
      mechanism_free = entry.broken_solutions.find { |b| b.id == "mechanism_free" }
      assert mechanism_free, "#{entry.name}: missing broken/mechanism_free.rb (or its meta.yml broken: entry)"

      result = @pool.rollout_task(task: mechanism_free.task)
      refute result.success?, "#{entry.name}/mechanism_free: expected the grader to reject a mechanism-ignorant solution, but it passed"
    end
  end

  # BRIEF §6/AC7: prove, against the real pool, that coverage attributed to
  # a task's solution contains only the solution - not the grader, not any
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

  def broken_result(entry, id)
    broken = entry.broken_solutions.find { |b| b.id == id } || raise("no such broken solution #{id.inspect} for #{entry.name}")
    @pool.rollout_task(task: broken.task)
  end

  def assert_broken_fails_on(entry, id, example_name)
    result = broken_result(entry, id)
    refute result.success?, "#{entry.name}/#{id}: expected broken solution to fail"
    assert_failed result, example_name
    result
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
