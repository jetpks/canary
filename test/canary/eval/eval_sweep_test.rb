require "test_helper"
require "tmpdir"
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

  # AC10: 3x the worst-case spend if every configured call maxed out
  # max_tokens, against a fixed model set/task count/price table so the
  # expected number is hand-computable rather than re-deriving the
  # production config's own real numbers here.
  def test_spend_cap_derivation_is_3x_the_worst_case_output_spend_rounded_up
    price_table = {
      "hidden-and-visible" => {input_token_price: 0, output_token_price: 0.00001},
      "hidden-only" => {input_token_price: 0, output_token_price: 0.00002}
    }

    cap, lines = EvalSweep.spend_cap_derivation(
      tasks_count: 10,
      hidden_models: ["hidden-and-visible", "hidden-only"],
      visible_models: ["hidden-and-visible"],
      price_table: price_table,
      max_tokens: 100
    )

    # hidden-and-visible: (10 tasks x HIDDEN_K hidden) + (10 tasks x VISIBLE_K visible) calls
    # hidden-only:        (10 tasks x HIDDEN_K hidden) calls, no visible-arm membership
    hidden_and_visible_calls = (10 * EvalSweep::HIDDEN_K) + (10 * EvalSweep::VISIBLE_K)
    hidden_only_calls = 10 * EvalSweep::HIDDEN_K
    worst_case = (hidden_and_visible_calls * 100 * 0.00001) + (hidden_only_calls * 100 * 0.00002)
    expected_cap = (worst_case * 3).ceil

    assert_equal expected_cap, cap
    assert_equal 4, lines.size
    assert_match(/hidden-and-visible.*#{hidden_and_visible_calls} calls/, lines[0])
    assert_match(/hidden-only.*#{hidden_only_calls} calls/, lines[1])
    assert_match(/worst case sum/, lines[2])
    assert_match(/cap.*\$#{expected_cap}/, lines[3])
  end

  def test_spend_cap_derivation_excludes_a_model_configured_in_neither_arm_it_was_asked_about
    price_table = {"unused-model" => {input_token_price: 0, output_token_price: 0.00001}}

    cap, lines = EvalSweep.spend_cap_derivation(
      tasks_count: 10, hidden_models: [], visible_models: [], price_table: price_table, max_tokens: 100
    )

    assert_equal 0, cap
    assert_equal ["  worst case sum: $0.0000", "  cap (3x worst case, rounded up): $0"], lines
  end

  def test_spend_cap_derivation_defaults_to_the_real_configured_models_and_price_table
    cap, lines = EvalSweep.spend_cap_derivation(tasks_count: 1)

    assert_operator cap, :>, 0
    assert_equal (EvalSweep::HIDDEN_MODELS + EvalSweep::VISIBLE_MODELS).uniq.size + 2, lines.size
  end

  # AC4 / I21 F3 correction: summary.md itself must carry actual spend and
  # the full cap-derivation lines, not just the runner's stdout.
  def test_write_summary_includes_actual_spend_and_the_cap_derivation
    records = [
      Canary::Eval::Record.new(
        schema_version: 1, task_name: "t1", model: "claude-haiku-4-5-20251001", sample_index: 0,
        render_mode: :hidden, scored: true, passed: true, input_tokens: 100, output_tokens: 200
      )
    ]
    cap, cap_lines = EvalSweep.spend_cap_derivation(tasks_count: 1)

    Dir.mktmpdir do |run_dir|
      path = EvalSweep.write_summary(records, run_dir, cap_lines)
      summary = File.read(path)

      expected_spend = EvalSweep.total_spend(records)
      assert_match(/actual spend \(from recorded token usage x price table\): \$#{Regexp.escape(format("%.4f", expected_spend))}/, summary)
      cap_lines.each { |line| assert_includes summary, line }
      assert_operator cap, :>, 0
    end
  end
end
