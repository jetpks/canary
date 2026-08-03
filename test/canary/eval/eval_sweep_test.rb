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

  # A model configured in either arm with no MODEL_PROVIDERS entry would
  # raise (fetch, not []) the moment run_arm tried to route it - catching
  # that here, offline, is cheaper than catching it mid-sweep.
  def test_every_configured_model_has_a_declared_provider
    (EvalSweep::HIDDEN_MODELS + EvalSweep::VISIBLE_MODELS).uniq.each do |model|
      assert EvalSweep::MODEL_PROVIDERS.key?(model), "#{model} has no declared provider"
    end
  end

  # Likewise for PRICE_TABLE - record_cost's own fetch would raise on a
  # configured model missing a price entry.
  def test_every_configured_model_has_a_price_table_entry
    (EvalSweep::HIDDEN_MODELS + EvalSweep::VISIBLE_MODELS).uniq.each do |model|
      assert EvalSweep::PRICE_TABLE.key?(model), "#{model} has no price table entry"
    end
  end

  def test_visible_models_are_both_anthropic_anchors_per_ac8
    assert_equal ["claude-haiku-4-5-20251001", "claude-sonnet-5"], EvalSweep::VISIBLE_MODELS.sort
  end

  def test_canary_sweep_skip_is_empty_by_default
    assert_empty EvalSweep.skipped_models
  end

  def test_canary_sweep_skip_parses_a_comma_separated_list
    ENV["CANARY_SWEEP_SKIP"] = "claude-sonnet-5, qwen/qwen3-coder"

    assert_equal ["claude-sonnet-5", "qwen/qwen3-coder"], EvalSweep.skipped_models
  ensure
    ENV.delete("CANARY_SWEEP_SKIP")
  end
end
