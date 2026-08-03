#!/usr/bin/env ruby

require_relative "../lib/canary"
require "fileutils"
require "json"

# Runs the I19-widened sweep shape and commits the resulting
# Canary::Eval::Record set, and the raw completions that produced them,
# under results/: 13 tasks x k=3 x the 10 HIDDEN_MODELS hidden, plus the
# same 13 tasks x k=1 x both Anthropic anchors grader-visible (AC8) - 416
# live calls total at today's configuration.
#
# Records and completions for one run live together under one
# results/run-<timestamp>/ directory, and a later run lands in its own
# fresh directory rather than overwriting an earlier one's evidence -
# results/sweep.jsonl, I15's run, is exactly the run this replaces, and it
# stays on disk untouched as a result (I15 F2: a run you can't re-score is
# a run you have to re-buy). Both files are written incrementally, as each
# record/completion lands, rather than batched at the end: an exception on
# call 90 must not cost the 89 samples already paid for.
#
# Opt-in the same way the rest of the suite is: nothing reads .env or
# spends a cent unless CANARY_LIVE=1 is set (test/test_helper.rb's own
# .env-loading gate, mirrored here rather than shared, since a test-only
# convenience has no business becoming a runtime dependency of bin/).
module EvalSweep
  # I19 follow-up 3 ruling: the earlier target list (qwen3-coder,
  # deepseek-chat, kimi-k2, llama-3.3-70b, gpt-oss-120b, mistral-large) was
  # the 2024-2025 generation still sitting on OpenRouter's catalog, not the
  # current one - this corpus needs to band against current-generation open
  # models. Every id below verified live against OpenRouter's GET /models
  # (337 models, 2026-08-03) by exact id match:
  #   deepseek/deepseek-v4-flash    hf: deepseek-ai/DeepSeek-V4-Flash
  #   deepseek/deepseek-v4-pro      hf: deepseek-ai/DeepSeek-V4-Pro
  #   moonshotai/kimi-k3            hf: moonshotai/Kimi-K3
  #   moonshotai/kimi-k2.7-code     hf: moonshotai/Kimi-K2.7-Code (Fireworks
  #                                 spells this kimi-k2p7-code)
  #   qwen/qwen3-coder-plus         current Qwen flagship coder tier (pricier,
  #                                 larger-context than qwen3-coder-flash/-next)
  #   qwen/qwen3.7-max              current Qwen flagship general/instruct tier
  #                                 ("Max" has been Alibaba's top tier since
  #                                 Turbo/Plus/Max; pricier than qwen3.7-plus)
  #   z-ai/glm-5.2                  hf: zai-org/GLM-5.2
  #
  # Fireworks probe (Audit D: same weights, second serving stack, so pass@k
  # disagreement bounds serving variance rather than model-generation delta) -
  # deepseek-v4-flash, on both OpenRouter and Fireworks. Unlike the retired
  # gpt-oss-120b probe (kept only a context_length match), this pairing has
  # BOTH context_length (1,048,576 on each side) AND modality (text->text, no
  # image input, on each side) agreement, plus OpenRouter's own
  # canonical_slug (deepseek/deepseek-v4-flash-20260423) and hugging_face_id
  # showing no name rotation - the strongest same-weights evidence found
  # across any candidate (Kimi K3/K2.7-code and GLM-5.2 also matched on
  # context_length+modality when checked, but DeepSeek V4 Flash was already
  # required in this set on OpenRouter, so pairing it needs no additional
  # model identity and it is the cheapest of the viable candidates).
  HIDDEN_MODELS = [
    "claude-haiku-4-5-20251001", "claude-sonnet-5",
    "deepseek/deepseek-v4-flash", "deepseek/deepseek-v4-pro",
    "moonshotai/kimi-k3", "moonshotai/kimi-k2.7-code",
    "qwen/qwen3-coder-plus", "qwen/qwen3.7-max", "z-ai/glm-5.2",
    "accounts/fireworks/models/deepseek-v4-flash"
  ].freeze
  # Both Anthropic anchors, per AC8 - not just the one this sweep used before.
  VISIBLE_MODELS = ["claude-haiku-4-5-20251001", "claude-sonnet-5"].freeze
  HIDDEN_K = 3
  VISIBLE_K = 1

  # Which provider endpoint each configured model routes through. A model
  # missing here is a configuration error (MODEL_PROVIDERS.fetch raises),
  # not a silent default - the two new endpoints are cheap to add a line
  # for and a wrong-by-default provider would be an expensive mistake.
  MODEL_PROVIDERS = {
    "claude-haiku-4-5-20251001" => :anthropic,
    "claude-sonnet-5" => :anthropic,
    "deepseek/deepseek-v4-flash" => :openrouter,
    "deepseek/deepseek-v4-pro" => :openrouter,
    "moonshotai/kimi-k3" => :openrouter,
    "moonshotai/kimi-k2.7-code" => :openrouter,
    "qwen/qwen3-coder-plus" => :openrouter,
    "qwen/qwen3.7-max" => :openrouter,
    "z-ai/glm-5.2" => :openrouter,
    "accounts/fireworks/models/deepseek-v4-flash" => :fireworks
  }.freeze

  PROVIDER_BASE_URLS = {
    openrouter: "https://openrouter.ai/api/v1",
    fireworks: "https://api.fireworks.ai/inference/v1"
  }.freeze

  PROVIDER_ENV_KEYS = {
    anthropic: "ANTHROPIC_API_KEY",
    openrouter: "OPENROUTER_API_KEY",
    fireworks: "FIREWORKS_API_KEY"
  }.freeze

  # $/token. Anthropic prices current as of 2026-08-02 (Haiku 4.5 $1/$5 per
  # MTok in/out; Sonnet 5 $2/$10 through its 2026-08-31 introductory window,
  # standard $3/$15 from 2026-09-01). OpenRouter prices are the exact
  # per-token "prompt"/"completion" figures from its own GET /models response
  # (2026-08-03) - the live source of truth for that endpoint, no unit
  # conversion needed since it already reports $/token (base tier; several of
  # these models have higher tiered rates past 32k/128k prompt tokens that
  # this table does not model, matching how the base rate was used for every
  # OpenRouter model in earlier follow-ups). Fireworks (deepseek-v4-flash) is
  # the Standard-tier rate from docs.fireworks.ai/serverless/pricing
  # (2026-08-03): $0.14/MTok input, $0.28/MTok output.
  PRICE_TABLE = {
    "claude-haiku-4-5-20251001" => {input_token_price: 1.0 / 1_000_000, output_token_price: 5.0 / 1_000_000},
    "claude-sonnet-5" => {input_token_price: 2.0 / 1_000_000, output_token_price: 10.0 / 1_000_000},
    "deepseek/deepseek-v4-flash" => {input_token_price: 0.00000014, output_token_price: 0.00000028},
    "deepseek/deepseek-v4-pro" => {input_token_price: 0.000000435, output_token_price: 0.00000087},
    "moonshotai/kimi-k3" => {input_token_price: 0.000003, output_token_price: 0.000015},
    "moonshotai/kimi-k2.7-code" => {input_token_price: 0.00000073, output_token_price: 0.0000035},
    "qwen/qwen3-coder-plus" => {input_token_price: 0.00000065, output_token_price: 0.00000325},
    "qwen/qwen3.7-max" => {input_token_price: 0.000001475, output_token_price: 0.000004425},
    "z-ai/glm-5.2" => {input_token_price: 0.00000119, output_token_price: 0.00000374},
    "accounts/fireworks/models/deepseek-v4-flash" => {input_token_price: 0.14 / 1_000_000, output_token_price: 0.28 / 1_000_000}
  }.freeze

  # Per-model thinking-effort override, merged into the request body via
  # Providers::OpenAICompat's extra_body_by_model (see that file). The
  # current-generation open models in HIDDEN_MODELS are reasoning-class
  # across the board (unlike the earlier target list) - the goal is the
  # lowest effort that still yields visible text within max_tokens, not
  # disabling reasoning outright (verified live: this sweep measures coding
  # capability through a text answer, not reasoning depth).
  #
  # OpenRouter's unified mechanism (docs.openrouter.ai/use-cases/reasoning-tokens,
  # 2026-08-03): {"reasoning": {"effort": "low"}} in the request body;
  # requesting an effort a model doesn't support maps to that model's own
  # nearest supported level rather than erroring (confirmed live per-model
  # supported_efforts: deepseek-v4-flash/pro and glm-5.2 only expose
  # ["xhigh","high"], so "low" here actually runs at their floor of "high";
  # kimi-k3 exposes ["max","high","low"], so "low" here is an exact match;
  # kimi-k2.7-code and qwen3.7-max don't enumerate supported_efforts in their
  # GET /models entries at all, so "low" here relies on that same
  # nearest-match behavior). qwen/qwen3-coder-plus is deliberately absent:
  # its GET /models entry does not list "reasoning" in supported_parameters
  # at all - it is not a reasoning model and needs no override.
  #
  # Fireworks' mechanism is genuinely different per-family (the human's own
  # warning, confirmed from docs.fireworks.ai/guides/reasoning): a
  # reasoning_effort request-body string ("low"/"medium"/"high") OR an
  # Anthropic-compatible thinking: {type:, budget_tokens:} object - never
  # both, sending both is a validation error. For Harmony-format models
  # specifically (OpenAI's gpt-oss family, not used here after the probe
  # swap to deepseek-v4-flash) reasoning_effort is further restricted to
  # exactly "low"/"medium"/"high" - "none"/false/an integer all error. The
  # Fireworks probe here (deepseek-v4-flash, not Harmony-format) uses the
  # plain reasoning_effort string.
  THINKING_EFFORT = {
    "deepseek/deepseek-v4-flash" => {reasoning: {effort: "low"}},
    "deepseek/deepseek-v4-pro" => {reasoning: {effort: "low"}},
    "moonshotai/kimi-k3" => {reasoning: {effort: "low"}},
    "moonshotai/kimi-k2.7-code" => {reasoning: {effort: "low"}},
    "qwen/qwen3.7-max" => {reasoning: {effort: "low"}},
    "z-ai/glm-5.2" => {reasoning: {effort: "low"}},
    "accounts/fireworks/models/deepseek-v4-flash" => {reasoning_effort: "low"}
  }.freeze

  # Sized well above the worst case, not tight against it. Per-model worst
  # case = that model's total call count (hidden 18 tasks x k=3, plus 18 x
  # k=1 for the two now-visible anchors) x max_tokens=4096
  # (Providers::Anthropic::DEFAULT_MAX_TOKENS/Providers::OpenAICompat::DEFAULT_MAX_TOKENS)
  # x its output_token_price, ignoring input cost as Anthropic's own
  # original estimate did. I20 widens the corpus from 13 to 18 tasks (a
  # parallel lane), which raises the same per-model call counts from 39/52
  # to 54/72:
  #   haiku                72 calls x 4096 x $0.000005    = $1.475
  #   sonnet               72 calls x 4096 x $0.00001     = $2.949
  #   deepseek-v4-flash(OR) 54 x 4096 x $0.00000028   = $0.062
  #   deepseek-v4-pro(OR)   54 x 4096 x $0.00000087   = $0.192
  #   kimi-k3               54 x 4096 x $0.000015     = $3.318
  #   kimi-k2.7-code        54 x 4096 x $0.0000035    = $0.774
  #   qwen3-coder-plus      54 x 4096 x $0.00000325   = $0.719
  #   qwen3.7-max           54 x 4096 x $0.000004425  = $0.979
  #   glm-5.2               54 x 4096 x $0.00000374   = $0.827
  #   deepseek-v4-flash(FW) 54 x 4096 x $0.00000028   = $0.062
  # sums to ~$11.357 worst case across the widened 576-call sweep. The
  # previous $25 cap would leave only ~2.2x headroom over this - so the cap
  # is raised to $35, restoring >3x headroom (35/11.357 =~ 3.08x), the same
  # order of margin every prior version of this cap held.
  SPEND_CAP_DOLLARS = 35.0

  RESULTS_DIR = File.expand_path("../results", __dir__)
  LIVE_ENV_FILE = File.expand_path("../.env", __dir__)

  def self.load_env!(models:)
    abort "CANARY_LIVE=1 is required to run the live sweep" unless ENV["CANARY_LIVE"]

    if File.exist?(LIVE_ENV_FILE)
      File.foreach(LIVE_ENV_FILE) do |line|
        next if line.lstrip.start_with?("#") || !line.include?("=")

        name, value = line.chomp.split("=", 2)
        ENV[name.strip] ||= value.strip.delete_prefix('"').delete_suffix('"')
      end
    end

    providers_in_use(models).each do |kind|
      env_key = PROVIDER_ENV_KEYS.fetch(kind)
      abort "CANARY_LIVE is set but no #{env_key} was loaded - is .env present?" unless ENV[env_key]
    end
  end

  # A model dropped from a preflight check has no business staying in the
  # sweep - the sweep lane, confined to results/**, cannot edit this file
  # to remove it, so a comma-separated env var is the drop mechanism
  # instead. Read once at run start and applied to both arms; nothing else
  # this run touches needs to know why a model is missing.
  def self.skipped_models
    (ENV["CANARY_SWEEP_SKIP"] || "").split(",").map(&:strip).reject(&:empty?)
  end

  # The distinct provider kinds a set of models actually needs, in the
  # order MODEL_PROVIDERS' own declarations imply - used both to know
  # which credentials load_env! must demand and which provider instances
  # +run+ actually has to build.
  def self.providers_in_use(models)
    models.map { |model| MODEL_PROVIDERS.fetch(model) }.uniq
  end

  def self.build_provider(kind, models)
    case kind
    when :anthropic
      Canary::Providers::Anthropic.new
    when :openrouter, :fireworks
      extra_body_by_model = models.to_h { |model| [model, THINKING_EFFORT.fetch(model, {})] }
      Canary::Providers::OpenAICompat.new(
        base_url: PROVIDER_BASE_URLS.fetch(kind), api_key: ENV.fetch(PROVIDER_ENV_KEYS.fetch(kind)),
        extra_body_by_model: extra_body_by_model
      )
    else
      raise ArgumentError, "unknown provider kind: #{kind.inspect}"
    end
  end

  # One fresh directory per run, so a rerun supersedes rather than
  # overwrites - see the module comment.
  def self.new_run_dir
    File.join(RESULTS_DIR, Time.now.utc.strftime("run-%Y%m%dT%H%M%SZ"))
  end

  def self.run
    skip = skipped_models
    hidden_models = HIDDEN_MODELS - skip
    visible_models = VISIBLE_MODELS - skip
    puts "CANARY_SWEEP_SKIP dropped: #{skip.join(', ')}" unless skip.empty?

    load_env!(models: hidden_models + visible_models)

    tasks = Canary::TaskRepo.all
    total_calls = (tasks.size * HIDDEN_K * hidden_models.size) + (tasks.size * VISIBLE_K * visible_models.size)
    budget = Canary::Sampler::Budget.new(max_samples: total_calls)
    spend_guard = Canary::Sampler::SpendGuard.new(max_dollars: SPEND_CAP_DOLLARS, price_table: PRICE_TABLE)

    run_dir = new_run_dir
    FileUtils.mkdir_p(run_dir)
    records_path = File.join(run_dir, "sweep.jsonl")
    completions_path = File.join(run_dir, "completions.jsonl")

    # One provider instance per distinct endpoint the configured models
    # actually use - Budget/SpendGuard/RecordSink are shared across every
    # provider's Sampler instance below since all three are plain mutable
    # counters/appenders with no provider awareness of their own.
    all_models = hidden_models + visible_models
    providers = providers_in_use(all_models).to_h do |kind|
      [kind, build_provider(kind, all_models.select { |model| MODEL_PROVIDERS.fetch(model) == kind })]
    end
    record_sink = Canary::Sampler::RecordSink.new(path: completions_path)
    samplers = providers.transform_values { |provider| Canary::Sampler.new(provider: provider, budget: budget, record_sink: record_sink, spend_guard: spend_guard) }
    append_record = ->(record) { File.open(records_path, "a") { |f| f.puts(JSON.generate(record.to_h)) } }

    puts "spend guard cap: $#{SPEND_CAP_DOLLARS}"
    puts "budget cap: #{total_calls} samples"
    puts "hidden arm: #{tasks.size} tasks x k=#{HIDDEN_K} x #{hidden_models.join(', ')}"
    hidden = run_arm(samplers: samplers, tasks: tasks, models: hidden_models, k: HIDDEN_K, grader: false, &append_record)

    puts "grader-visible arm: #{tasks.size} tasks x k=#{VISIBLE_K} x #{visible_models.join(', ')}"
    visible = run_arm(samplers: samplers, tasks: tasks, models: visible_models, k: VISIBLE_K, grader: true, &append_record)

    records = hidden + visible
    report_spend(records)
    write_summary(records, run_dir)
    puts "wrote #{records.size} records to #{records_path}"
    puts "wrote completions to #{completions_path}"
    records_path
  end

  # Groups +models+ by declared provider and runs each group through its
  # own Runner instance against the matching pre-built sampler - the
  # split is invisible to the caller (still one flat Array of Records
  # back), and a single-provider model set (today's config) collapses to
  # exactly the one runner.call the pre-multi-provider code made.
  def self.run_arm(samplers:, tasks:, models:, k:, grader:, &on_record)
    models.group_by { |model| MODEL_PROVIDERS.fetch(model) }.flat_map do |kind, models_for_kind|
      runner = Canary::Eval::Runner.new(sampler: samplers.fetch(kind))
      runner.call(entries: tasks, models: models_for_kind, k: k, grader: grader, &on_record)
    end
  end

  def self.record_cost(record)
    return 0.0 unless record.input_tokens && record.output_tokens

    rate = PRICE_TABLE.fetch(record.model)
    (record.input_tokens * rate[:input_token_price]) + (record.output_tokens * rate[:output_token_price])
  end

  def self.report_spend(records)
    spend = records.sum { |record| record_cost(record) }
    tripped = records.any? { |record| record.non_score_reason == :spend_exceeded }
    puts "spend guard tripped: #{tripped}"
    puts format("actual spend (from recorded token usage x price table): $%.4f", spend)
  end

  def self.write_summary(records, run_dir)
    lines = ["# Canary eval sweep", ""]
    records.group_by { |record| [record.model, record.render_mode] }.sort.each do |(model, mode), arm_records|
      lines.concat(arm_section(model, mode, arm_records))
    end

    path = File.join(run_dir, "summary.md")
    File.write(path, lines.join("\n"))
    puts "wrote summary to #{path}"
    path
  end

  def self.arm_section(model, mode, arm_records)
    k = arm_records.group_by(&:task_name).values.map(&:size).max
    report = Canary::Eval::Report.new(arm_records)

    lines = ["## #{model} / #{mode}", ""]
    lines << "- scored: #{report.scored_count}, non_score: #{report.non_score_count}"
    lines << "- non_scores_by_reason: #{report.non_scores_by_reason}"
    lines << "- pass_at_1: #{report.pass_at_1.inspect} (tasks_counted: #{report.tasks_counted(1)})"
    lines << "- pass_at_#{k}: #{report.pass_at_k(k).inspect} (tasks_counted: #{report.tasks_counted(k)})" if k && k > 1
    lines << ""
    lines.concat(task_table(arm_records))
    lines << ""
  end

  def self.task_table(arm_records)
    lines = ["| task | scored | passed | non_score_reasons |", "|---|---|---|---|"]
    arm_records.group_by(&:task_name).sort.each do |task_name, task_records|
      task_report = Canary::Eval::Report.new(task_records)
      passed = task_records.count(&:passed)
      lines << "| #{task_name} | #{task_report.scored_count} | #{passed} | #{task_report.non_scores_by_reason} |"
    end
    lines
  end
end

EvalSweep.run if $PROGRAM_NAME == __FILE__
