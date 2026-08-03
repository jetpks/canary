require "test_helper"
require_relative "../../../bin/eval_sweep"

# Proves bin/eval_sweep.rb's results/ layout offline, without CANARY_LIVE or
# a network call: a run directory is fresh each time, distinct from
# results/sweep.jsonl (I15's run, superseded rather than overwritten), and
# holds both a records file and a completions file together.
class EvalSweepTest < Minitest::Test
  def test_new_run_dir_is_a_fresh_directory_under_results_distinct_from_i15s_artifact
    run_dir = EvalSweep.new_run_dir

    assert_equal EvalSweep::RESULTS_DIR, File.dirname(run_dir)
    refute_equal File.join(EvalSweep::RESULTS_DIR, "sweep.jsonl"), run_dir
    assert_match(/\Arun-\d{8}T\d{6}Z\z/, File.basename(run_dir))
  end
end
