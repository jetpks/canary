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

  # I24: with no model given, select_models falls back to the full-sweep
  # path - the full configured sets, narrowed only by CANARY_SWEEP_SKIP,
  # exactly EvalSweep.run's pre-I24 behavior.
  def test_select_models_with_no_model_returns_the_full_configured_sets_and_no_skip
    hidden, visible, skip = EvalSweep.select_models(nil)

    assert_equal EvalSweep::HIDDEN_MODELS, hidden
    assert_equal EvalSweep::VISIBLE_MODELS, visible
    assert_empty skip
  end

  def test_select_models_with_no_model_still_honors_canary_sweep_skip
    ENV["CANARY_SWEEP_SKIP"] = "claude-sonnet-5"

    hidden, visible, skip = EvalSweep.select_models(nil)

    refute_includes hidden, "claude-sonnet-5"
    refute_includes visible, "claude-sonnet-5"
    assert_equal ["claude-sonnet-5"], skip
  ensure
    ENV.delete("CANARY_SWEEP_SKIP")
  end

  # A visible-arm model (also a hidden-arm model, per
  # test_visible_models_are_both_anthropic_anchors_per_ac8) narrows both
  # arms to just itself.
  def test_select_models_with_a_visible_model_narrows_both_arms_to_it
    hidden, visible, skip = EvalSweep.select_models("claude-sonnet-5")

    assert_equal ["claude-sonnet-5"], hidden
    assert_equal ["claude-sonnet-5"], visible
    assert_empty skip
  end

  # Every OpenRouter/Fireworks model is hidden-only - selecting one must
  # leave the visible arm empty rather than running it anyway.
  def test_select_models_with_a_hidden_only_model_leaves_the_visible_arm_empty
    hidden, visible, _skip = EvalSweep.select_models("deepseek/deepseek-v4-flash")

    assert_equal ["deepseek/deepseek-v4-flash"], hidden
    assert_empty visible
  end

  # AC3: an unknown model aborts before any env/key demand, naming the known
  # models - MODEL_PROVIDERS is the authority on what's known.
  def test_select_models_aborts_on_an_unknown_model_naming_the_known_models
    _out, err = capture_io do
      assert_raises(SystemExit) { EvalSweep.select_models("not-a-real-model") }
    end

    assert_match(/not-a-real-model/, err)
    EvalSweep::MODEL_PROVIDERS.each_key { |model| assert_includes err, model }
  end

  # AC3: the narrowed-cap defect this closes - EvalSweep.run used to derive
  # the spend cap from the full configured sets regardless of what
  # select_models actually narrowed to. Proven here at the seam self.run
  # wires together: the same narrowed sets select_models returns, fed into
  # spend_cap_derivation, must yield a smaller cap than the full-set default.
  def test_spend_cap_derivation_follows_a_single_model_selection_narrower_than_the_full_sweep
    hidden, visible, _skip = EvalSweep.select_models("deepseek/deepseek-v4-flash")

    narrowed_cap, = EvalSweep.spend_cap_derivation(tasks_count: 10, hidden_models: hidden, visible_models: visible)
    full_cap, = EvalSweep.spend_cap_derivation(tasks_count: 10)

    assert_operator narrowed_cap, :<, full_cap
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
  # the full cap-derivation lines, not just the runner's stdout. Uses a real
  # TaskRepo task name (an authored one) rather than a fabricated "t1" -
  # write_summary looks provenance up from Canary::TaskRepo.all by
  # task_name and raises on a name the repo doesn't know.
  def test_write_summary_includes_actual_spend_and_the_cap_derivation
    records = [
      Canary::Eval::Record.new(
        schema_version: 1, task_name: "block_memoizer", model: "claude-haiku-4-5-20251001", sample_index: 0,
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

  # AC1: every :openrouter model's extra body carries exactly one pinned
  # order entry and allow_fallbacks: false, and it survives alongside
  # THINKING_EFFORT's reasoning fragment where one exists (the two never
  # collide - disjoint top-level keys).
  def test_every_openrouter_model_has_a_provider_pin
    EvalSweep::MODEL_PROVIDERS.select { |_model, kind| kind == :openrouter }.each_key do |model|
      assert EvalSweep::PROVIDER_PINS.key?(model), "#{model} has no provider pin"
    end
  end

  def test_provider_pins_cover_only_openrouter_models
    EvalSweep::PROVIDER_PINS.each_key do |model|
      assert_equal :openrouter, EvalSweep::MODEL_PROVIDERS.fetch(model)
    end
  end

  def test_extra_body_for_a_pinned_model_carries_exactly_one_order_entry_and_no_fallbacks
    EvalSweep::PROVIDER_PINS.each do |model, tag|
      assert_equal({order: [tag], allow_fallbacks: false}, EvalSweep.extra_body_for(model)[:provider])
    end
  end

  def test_extra_body_for_a_pinned_model_still_carries_its_thinking_effort
    body = EvalSweep.extra_body_for("deepseek/deepseek-v4-flash")

    assert_equal({effort: "low"}, body[:reasoning])
    assert_equal({order: ["alibaba/fp8"], allow_fallbacks: false}, body[:provider])
  end

  def test_extra_body_for_a_pinned_model_with_no_thinking_effort_carries_only_the_pin
    body = EvalSweep.extra_body_for("qwen/qwen3-coder-plus")

    refute body.key?(:reasoning)
    assert_equal({order: ["alibaba/fp8"], allow_fallbacks: false}, body[:provider])
  end

  # No :anthropic or :fireworks model carries a provider key - anthropic
  # models never pass through extra_body_for at all (build_provider's
  # :anthropic branch), and the Fireworks-direct model is deliberately
  # absent from PROVIDER_PINS since it hits a different API entirely.
  def test_no_non_openrouter_model_carries_a_provider_key
    (EvalSweep::MODEL_PROVIDERS.keys - EvalSweep::PROVIDER_PINS.keys).each do |model|
      refute EvalSweep.extra_body_for(model).key?(:provider), "#{model} unexpectedly carries a provider key"
    end
  end

  # AC3 / R11(b): a model/mode section splits into an authored sub-report
  # and a sourced sub-report, each with its own pass_at_1/tasks_counted -
  # proven here by checking neither sub-report's tasks_counted pools the
  # other's task into its own denominator.
  def test_write_summary_partitions_authored_and_sourced_sub_reports_with_no_pooled_rate
    authored_task = Canary::TaskRepo.all.find { |entry| entry.provenance == "authored" }.name
    sourced_task = Canary::TaskRepo.all.find { |entry| entry.provenance == "sourced" }.name
    records = [
      Canary::Eval::Record.new(
        schema_version: 1, task_name: authored_task, model: "claude-haiku-4-5-20251001", sample_index: 0,
        render_mode: :hidden, scored: true, passed: true, input_tokens: 10, output_tokens: 10
      ),
      Canary::Eval::Record.new(
        schema_version: 1, task_name: sourced_task, model: "claude-haiku-4-5-20251001", sample_index: 0,
        render_mode: :hidden, scored: true, passed: false, input_tokens: 10, output_tokens: 10
      )
    ]
    _cap, cap_lines = EvalSweep.spend_cap_derivation(tasks_count: 2)

    Dir.mktmpdir do |run_dir|
      path = EvalSweep.write_summary(records, run_dir, cap_lines)
      summary = File.read(path)

      assert_includes summary, "### authored"
      assert_includes summary, "### sourced"
      assert_includes summary, "| #{authored_task} |"
      assert_includes summary, "| #{sourced_task} |"
      assert_equal 2, summary.scan("(tasks_counted: 1)").size
      refute_includes summary, "(tasks_counted: 2)"
    end
  end

  # AC3: a record naming a task the repo doesn't carry fails loudly rather
  # than pooling silently into either sub-report.
  def test_write_summary_raises_on_a_record_with_an_unknown_task_name
    records = [
      Canary::Eval::Record.new(
        schema_version: 1, task_name: "not-a-real-task", model: "claude-haiku-4-5-20251001", sample_index: 0,
        render_mode: :hidden, scored: true, passed: true, input_tokens: 10, output_tokens: 10
      )
    ]
    _cap, cap_lines = EvalSweep.spend_cap_derivation(tasks_count: 1)

    Dir.mktmpdir do |run_dir|
      assert_raises(KeyError) { EvalSweep.write_summary(records, run_dir, cap_lines) }
    end
  end
end
