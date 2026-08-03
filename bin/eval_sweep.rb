#!/usr/bin/env ruby

require_relative "../lib/canary"
require "fileutils"
require "json"

# Runs the I19-widened sweep shape and commits the resulting
# Canary::Eval::Record set, and the raw completions that produced them,
# under results/: 13 tasks x k=3 x the 9 HIDDEN_MODELS hidden, plus the
# same 13 tasks x k=1 x both Anthropic anchors grader-visible (AC8) - 377
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
  # openai/gpt-oss-120b, moonshotai/kimi-k2, meta-llama/llama-3.3-70b-instruct,
  # qwen/qwen3-coder and deepseek/deepseek-chat verified as exact, live ids
  # against OpenRouter's GET /models (2026-08-03). mistralai/mistral-large-2411
  # (the originally-requested id) has rotated off that catalog; substituted
  # mistralai/mistral-large-2512, the current live successor in the same
  # dated-release naming scheme (mistral-large-2407 and -2411 are both gone).
  #
  # Fireworks probe (Audit D: same weights, second serving stack, so pass@k
  # disagreement bounds serving variance rather than model-generation delta) -
  # openai/gpt-oss-120b, on both OpenRouter and Fireworks:
  #   - DeepSeek was ruled out first (see git history): OpenRouter's
  #     deepseek/deepseek-chat is DeepSeek-V3 (its own metadata); this
  #     account's Fireworks catalog has only the V4 generation. Not the same
  #     weights.
  #   - Kimi K2 was tried next and ALSO ruled out: OpenRouter's
  #     moonshotai/kimi-k2 is "Kimi K2 0711" (hugging_face_id
  #     moonshotai/Kimi-K2-Instruct, context_length 131072, text-only
  #     modality). This account's Fireworks catalog has no plain "kimi-k2" -
  #     only kimi-k2p6 and kimi-k2p7-code (context_length 262144, image-input
  #     capable) and kimi-k3 (context_length 1048576) - later generations,
  #     not the 0711 release OpenRouter serves. Not the same weights.
  #   - openai/gpt-oss-120b: OpenRouter's canonical_slug AND hugging_face_id
  #     both equal the id itself ("openai/gpt-oss-120b", no rotation, unlike
  #     deepseek-chat's canonical_slug pointing elsewhere) - gpt-oss is a
  #     single fixed OpenAI open-weight release, not a versioned lineage like
  #     DeepSeek/Kimi. context_length matches exactly on both sides: 131072
  #     (OpenRouter's own field) == 131072 (this account's Fireworks
  #     GET /v1/models entry). Best available same-weights evidence on this
  #     account's catalog - selected as the probe.
  #   Caveat, disclosed rather than routed around: gpt-oss is a
  #   reasoning-mandatory family (OpenRouter's own metadata:
  #   reasoning.mandatory == true; empirically confirmed earlier when
  #   gpt-oss-20b on Fireworks spent an entire 16-token budget on hidden
  #   reasoning_content with zero visible output) - this probe may fail the
  #   sweep lane's preflight on either side. That would be an honest null for
  #   Audit D, not a reason to swap the model again.
  HIDDEN_MODELS = [
    "claude-haiku-4-5-20251001", "claude-sonnet-5",
    "qwen/qwen3-coder", "deepseek/deepseek-chat", "moonshotai/kimi-k2",
    "meta-llama/llama-3.3-70b-instruct", "openai/gpt-oss-120b", "mistralai/mistral-large-2512",
    "accounts/fireworks/models/gpt-oss-120b"
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
    "qwen/qwen3-coder" => :openrouter,
    "deepseek/deepseek-chat" => :openrouter,
    "moonshotai/kimi-k2" => :openrouter,
    "meta-llama/llama-3.3-70b-instruct" => :openrouter,
    "openai/gpt-oss-120b" => :openrouter,
    "mistralai/mistral-large-2512" => :openrouter,
    "accounts/fireworks/models/gpt-oss-120b" => :fireworks
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
  # conversion needed since it already reports $/token. Fireworks
  # (gpt-oss-120b) is the Standard-tier rate from
  # docs.fireworks.ai/serverless/pricing (2026-08-03): $0.15/MTok input,
  # $0.60/MTok output.
  PRICE_TABLE = {
    "claude-haiku-4-5-20251001" => {input_token_price: 1.0 / 1_000_000, output_token_price: 5.0 / 1_000_000},
    "claude-sonnet-5" => {input_token_price: 2.0 / 1_000_000, output_token_price: 10.0 / 1_000_000},
    "qwen/qwen3-coder" => {input_token_price: 0.0000003, output_token_price: 0.000001},
    "deepseek/deepseek-chat" => {input_token_price: 0.0000002574, output_token_price: 0.0000010287},
    "moonshotai/kimi-k2" => {input_token_price: 0.00000057, output_token_price: 0.0000023},
    "meta-llama/llama-3.3-70b-instruct" => {input_token_price: 0.00000013, output_token_price: 0.0000004},
    "openai/gpt-oss-120b" => {input_token_price: 0.000000037, output_token_price: 0.00000017},
    "mistralai/mistral-large-2512" => {input_token_price: 0.0000005, output_token_price: 0.0000015},
    "accounts/fireworks/models/gpt-oss-120b" => {input_token_price: 0.15 / 1_000_000, output_token_price: 0.60 / 1_000_000}
  }.freeze

  # Sized well above the worst case, not tight against it. Per-model worst
  # case = that model's total call count (hidden 13 tasks x k=3, plus 13 x
  # k=1 for the two now-visible anchors) x max_tokens=4096
  # (Providers::Anthropic::DEFAULT_MAX_TOKENS/Providers::OpenAICompat::DEFAULT_MAX_TOKENS)
  # x its output_token_price, ignoring input cost as Anthropic's own
  # original estimate did:
  #   haiku   52 calls x 4096 x $0.000005  = $1.065
  #   sonnet  52 calls x 4096 x $0.00001   = $2.130
  #   qwen3-coder      39 x 4096 x $0.000001    = $0.160
  #   deepseek-chat    39 x 4096 x $0.0000010287 = $0.164
  #   kimi-k2          39 x 4096 x $0.0000023   = $0.367
  #   llama-3.3-70b    39 x 4096 x $0.0000004   = $0.064
  #   gpt-oss-120b(OR) 39 x 4096 x $0.00000017  = $0.027
  #   mistral-large    39 x 4096 x $0.0000015   = $0.240
  #   gpt-oss-120b(FW) 39 x 4096 x $0.0000006   = $0.096
  # sums to ~$4.31 worst case across the widened 377-call sweep; $15 keeps
  # over 3x headroom, the same order of margin the original $10 cap held
  # against its ~$2.73 worst case.
  SPEND_CAP_DOLLARS = 15.0

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

  def self.build_provider(kind)
    case kind
    when :anthropic
      Canary::Providers::Anthropic.new
    when :openrouter, :fireworks
      Canary::Providers::OpenAICompat.new(base_url: PROVIDER_BASE_URLS.fetch(kind), api_key: ENV.fetch(PROVIDER_ENV_KEYS.fetch(kind)))
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
    providers = providers_in_use(hidden_models + visible_models).to_h { |kind| [kind, build_provider(kind)] }
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
