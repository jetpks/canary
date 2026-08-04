require "test_helper"
require "tmpdir"
require "async"
require "tempfile"
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
    (EvalSweep::HIDDEN_MODELS + EvalSweep::VISIBLE_MODELS + EvalSweep::STUDIO_MODELS).uniq.each do |model|
      assert EvalSweep::MODEL_PROVIDERS.key?(model), "#{model} has no declared provider"
    end
  end

  # Likewise for PRICE_TABLE - record_cost's own fetch would raise on a
  # configured model missing a price entry.
  def test_every_configured_model_has_a_price_table_entry
    (EvalSweep::HIDDEN_MODELS + EvalSweep::VISIBLE_MODELS + EvalSweep::STUDIO_MODELS).uniq.each do |model|
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

  # AC1: a bare invocation (model: nil) must never pick up a studio model in
  # either arm - the local-serving arm only ever runs when named explicitly.
  def test_select_models_with_no_model_never_includes_a_studio_model
    hidden, visible, _skip = EvalSweep.select_models(nil)

    EvalSweep::STUDIO_MODELS.each do |model|
      refute_includes hidden, model
      refute_includes visible, model
    end
  end

  # AC2: each studio alias is selectable via the single-model positional
  # invocation, narrows to the hidden arm only, and routes through the
  # :studio provider kind.
  def test_each_studio_model_is_selectable_hidden_only_and_declares_the_studio_provider
    EvalSweep::STUDIO_MODELS.each do |model|
      hidden, visible, skip = EvalSweep.select_models(model)

      assert_equal [model], hidden
      assert_empty visible
      assert_empty skip
      assert_equal :studio, EvalSweep::MODEL_PROVIDERS.fetch(model)
    end
  end

  # AC2: every studio alias routes to the studio gateway.
  def test_studio_provider_base_url_is_the_studio_gateway
    assert_equal "https://studio.slush.systems/v1", EvalSweep::PROVIDER_BASE_URLS.fetch(:studio)
  end

  # AC2: every studio alias carries a $0.00 price row - local serving's true
  # per-token rate.
  def test_every_studio_model_has_a_zero_dollar_price_row
    EvalSweep::STUDIO_MODELS.each do |model|
      price = EvalSweep::PRICE_TABLE.fetch(model)

      assert_equal 0.0, price[:input_token_price]
      assert_equal 0.0, price[:output_token_price]
    end
  end

  # AC5: the studio provider is built with a read timeout generous enough to
  # survive model hot-load plus a full SWEEP_MAX_TOKENS generation.
  def test_studio_read_timeout_is_generous_enough_for_a_full_generation
    assert_operator EvalSweep::STUDIO_READ_TIMEOUT, :>=, 1800
  end

  # AC6: studio models get no THINKING_EFFORT override - the gateway's
  # strict schema may reject the unknown body field, and reasoning is left
  # at the model's own default.
  def test_studio_models_have_no_thinking_effort_entry
    EvalSweep::STUDIO_MODELS.each do |model|
      refute EvalSweep::THINKING_EFFORT.key?(model), "#{model} unexpectedly has a THINKING_EFFORT entry"
    end
  end

  # AC6: studio models get no PROVIDER_PINS entry - one backend exists by
  # construction, so there is nothing to pin.
  def test_studio_models_have_no_provider_pin
    EvalSweep::STUDIO_MODELS.each do |model|
      refute EvalSweep::PROVIDER_PINS.key?(model), "#{model} unexpectedly has a PROVIDER_PINS entry"
    end
  end

  # AC6: extra_body_for a studio model must stay a no-op merge, same as any
  # other model with no THINKING_EFFORT/PROVIDER_PINS entry.
  def test_extra_body_for_a_studio_model_is_empty
    EvalSweep::STUDIO_MODELS.each do |model|
      assert_empty EvalSweep.extra_body_for(model)
    end
  end

  # AC3: load_env! must not demand any credential for a studio-only model
  # set - the gateway takes no real auth (verified live).
  def test_load_env_does_not_abort_for_a_studio_only_model_set_with_no_credentials
    ENV["CANARY_LIVE"] = "1"

    EvalSweep.load_env!(models: ["qwen3-27b-optiq"])
  ensure
    ENV.delete("CANARY_LIVE")
  end

  # AC3: build_provider(:studio, ...) must not read any credential from
  # ENV - it passes STUDIO_API_KEY, a placeholder.
  def test_build_provider_for_studio_needs_no_credential
    provider = EvalSweep.build_provider(:studio, ["qwen3-27b-optiq"])

    assert_instance_of Canary::Providers::OpenAICompat, provider
  end

  # AC4: a $0-priced studio model never trips the spend guard, exercised
  # against the real SpendGuard collaborator (not a mock) with repeated
  # full-budget usage recorded against it.
  def test_a_zero_priced_studio_model_never_trips_the_spend_guard
    guard = Canary::Sampler::SpendGuard.new(max_dollars: 0, price_table: EvalSweep::PRICE_TABLE)

    5.times { guard.record!(model: "qwen3-27b-optiq", usage: {input_tokens: 1000, output_tokens: EvalSweep::SWEEP_MAX_TOKENS}) }

    refute guard.exceeded?
  end

  # AC4: spend_cap_derivation prints its zero-cost line and derives a $0 cap
  # for a studio-only selection, without aborting.
  def test_spend_cap_derivation_for_a_studio_only_selection_is_zero_and_prints_a_zero_cost_line
    hidden, visible, _skip = EvalSweep.select_models("qwen3-27b-optiq")

    cap, lines = EvalSweep.spend_cap_derivation(tasks_count: 10, hidden_models: hidden, visible_models: visible)

    assert_equal 0, cap
    assert_match(/qwen3-27b-optiq.*\$0\.0000/, lines[0])
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

  # I28 AC1: the studio gateway 502s on any second provider call issued
  # while another is in flight - run_arm's :studio branch must therefore
  # never let two of its provider calls overlap. Driven through run_arm
  # itself (the same code path EvalSweep.run uses), against a fake
  # provider that records the live in-flight count on every call.
  def test_run_arm_never_overlaps_provider_calls_for_a_studio_model
    concurrent = 0
    max_concurrent = 0
    fake = Canary::Providers::Fake.new do |model:, prompt:|
      concurrent += 1
      max_concurrent = concurrent if concurrent > max_concurrent
      Async::Task.current.sleep(0.01)
      concurrent -= 1
      Dry::Monads::Success(Canary::Providers::Sample.new(text: VALID_CODE_RESPONSE, raw: {usage: {input_tokens: 1, output_tokens: 1}}, stop_reason: :end_turn))
    end
    model = EvalSweep::STUDIO_MODELS.first

    records = EvalSweep.run_arm(samplers: {studio: build_fake_sampler(fake)}, tasks: [build_fixture_entry], models: [model], k: 5, grader: false)

    assert_equal 5, records.size
    assert_equal 1, max_concurrent, "expected no overlap for a :studio model, saw #{max_concurrent} calls in flight at once"
  end

  # I28 AC2: hosted provider kinds must keep their existing fan-out
  # unchanged - proven here (not assumed) by the same overlap-recording
  # fake, this time genuinely overlapping under run_arm's default
  # concurrency for a hosted (:anthropic) model.
  def test_run_arm_keeps_the_default_fan_out_for_a_hosted_model
    concurrent = 0
    max_concurrent = 0
    fake = Canary::Providers::Fake.new do |model:, prompt:|
      concurrent += 1
      max_concurrent = concurrent if concurrent > max_concurrent
      Async::Task.current.sleep(0.01)
      concurrent -= 1
      Dry::Monads::Success(Canary::Providers::Sample.new(text: VALID_CODE_RESPONSE, raw: {usage: {input_tokens: 1, output_tokens: 1}}, stop_reason: :end_turn))
    end
    model = "claude-haiku-4-5-20251001"

    records = EvalSweep.run_arm(samplers: {anthropic: build_fake_sampler(fake)}, tasks: [build_fixture_entry], models: [model], k: 10, grader: false)

    assert_equal 10, records.size
    assert_operator max_concurrent, :>, 1, "expected genuine overlap for a hosted model, fan-out regressed to serial"
    assert_operator max_concurrent, :<=, Canary::Eval::Runner::DEFAULT_CONCURRENCY
  end

  # I28: runner_concurrency itself - :studio pins to 1, every other kind
  # keeps Runner's own default.
  def test_runner_concurrency_pins_studio_to_one_and_leaves_other_kinds_at_the_default
    assert_equal 1, EvalSweep.runner_concurrency(:studio)
    assert_equal Canary::Eval::Runner::DEFAULT_CONCURRENCY, EvalSweep.runner_concurrency(:anthropic)
    assert_equal Canary::Eval::Runner::DEFAULT_CONCURRENCY, EvalSweep.runner_concurrency(:openrouter)
    assert_equal Canary::Eval::Runner::DEFAULT_CONCURRENCY, EvalSweep.runner_concurrency(:fireworks)
  end

  private

  VALID_CODE_RESPONSE = "Here you go:\n\n```ruby\nclass Adder\n  def self.call(a, b)\n    a + b\n  end\nend\n```\n"
  FIXTURES = File.expand_path("fixtures/task", __dir__)

  def build_fake_sampler(provider, max_samples: 20)
    Canary::Sampler.new(
      provider: provider,
      budget: Canary::Sampler::Budget.new(max_samples: max_samples),
      record_sink: Canary::Sampler::RecordSink.new(path: Tempfile.new(%w[eval_sweep_test_records .jsonl]).path)
    )
  end

  def build_fixture_entry
    Canary::TaskRepo::Entry.new(
      name: "eval_fixture_task",
      statement: "Implement Adder.call(a, b), returning their sum.",
      adapter: :minitest,
      reference: Canary::Task.new(solution_path: File.join(FIXTURES, "solution.rb"), test_path: File.join(FIXTURES, "grader.rb"), adapter: :minitest)
    )
  end
end
