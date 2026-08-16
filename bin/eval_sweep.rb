#!/usr/bin/env ruby

require_relative "../lib/canary"
require "fileutils"
require "json"

# Runs the sweep shape and commits the resulting Canary::Eval::Record set,
# and the raw completions that produced them, under results/: every task in
# Canary::TaskRepo.all x k=HIDDEN_K x HIDDEN_MODELS.size hidden, plus the
# same task count x k=VISIBLE_K x VISIBLE_MODELS.size grader-visible (AC8) -
# total live calls tracks the corpus and configured model set, not a fixed
# number that rots as either changes (see .run's total_calls).
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
#
# ARGV[0], if given, is a model id (see MODEL_PROVIDERS for the known set)
# that narrows both arms to that one model instead of the full configured
# set - a positional arg, not a flag, since it is this script's only
# selector and needs no OptionParser to carry it (see .select_models). With
# no ARGV given, CANARY_SWEEP_SKIP still narrows the full set as before.
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

  # I27 r12-studio-arm: five models behind jetpks/space-inference-gateway on
  # a Mac Studio, hot-swapped per request's model field - no auth, $0 true
  # marginal cost (already-owned hardware, no metered API). Every id
  # verified live against GET https://studio.slush.systems/v1/models by the
  # architect this session. Deliberately its own list rather than folded
  # into HIDDEN_MODELS: a bare bin/eval_sweep.rb invocation (no ARGV) must
  # stay byte-identical to the hosted-only sweep - a studio model only ever
  # runs when named explicitly via the single-model positional invocation
  # (see .select_models).
  STUDIO_MODELS = [
    "qwen3.6-35b-a3b-4bit", "qwen3.6-35b-a3b-8bit", "qwen3-27b-optiq",
    "qwen3-122b-a10b", "nemotron-3-super", "qwen3.8-27b-mxfp8-concurrent4",
    "qwen3.8-27b-mxfp8-concurrent1"
  ].freeze

  # I29 R12 phase 1 Arm H: seven hosted consumer-class open-weight models
  # spanning an active-parameter gradient (~3B to ~12B active, plus two
  # dense siblings - qwen3.6-27b and gemma-4-31b-it), bought as a later
  # `armh` run lane's per-model targets (one `bin/eval_sweep.rb <id>`
  # invocation per model). Every id verified live against GET
  # https://openrouter.ai/api/v1/models/<id>/endpoints (2026-08-04) - see
  # PROVIDER_PINS for the pinned route each carries. Deliberately its own
  # list rather than folded into HIDDEN_MODELS, same reasoning as
  # STUDIO_MODELS above: a bare bin/eval_sweep.rb invocation must stay
  # byte-identical to today's sweep - an Arm H model only ever runs when
  # named explicitly via the single-model positional invocation (see
  # .select_models).
  ARM_H_MODELS = [
    "qwen/qwen3.6-27b", "qwen/qwen3.6-35b-a3b", "google/gemma-4-26b-a4b-it",
    "google/gemma-4-31b-it", "openai/gpt-oss-120b", "qwen/qwen3.5-122b-a10b",
    "nvidia/nemotron-3-super-120b-a12b"
  ].freeze

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
    "accounts/fireworks/models/deepseek-v4-flash" => :fireworks,
    "qwen3.6-35b-a3b-4bit" => :studio,
    "qwen3.6-35b-a3b-8bit" => :studio,
    "qwen3-27b-optiq" => :studio,
    "qwen3-122b-a10b" => :studio,
    "nemotron-3-super" => :studio,
    "qwen3.8-27b-mxfp8-concurrent4" => :studio,
    "qwen3.8-27b-mxfp8-concurrent1" => :studio,
    "qwen/qwen3.6-27b" => :openrouter,
    "qwen/qwen3.6-35b-a3b" => :openrouter,
    "google/gemma-4-26b-a4b-it" => :openrouter,
    "google/gemma-4-31b-it" => :openrouter,
    "openai/gpt-oss-120b" => :openrouter,
    "qwen/qwen3.5-122b-a10b" => :openrouter,
    "nvidia/nemotron-3-super-120b-a12b" => :openrouter
  }.freeze

  PROVIDER_BASE_URLS = {
    openrouter: "https://openrouter.ai/api/v1",
    fireworks: "https://api.fireworks.ai/inference/v1",
    studio: "https://studio.slush.systems/v1"
  }.freeze

  # :studio deliberately has no entry here - the gateway takes no real
  # credential at all (verified live), so .load_env! demands nothing for it
  # and .build_provider passes STUDIO_API_KEY, a placeholder the gateway
  # never inspects.
  PROVIDER_ENV_KEYS = {
    anthropic: "ANTHROPIC_API_KEY",
    openrouter: "OPENROUTER_API_KEY",
    fireworks: "FIREWORKS_API_KEY"
  }.freeze

  STUDIO_API_KEY = "studio-gateway-ignores-auth"
  # A full 16_384-token generation behind a hot model load comfortably clears
  # OpenAICompat::DEFAULT_READ_TIMEOUT's 60s - this is a generous multiple of
  # that headroom, not a measured worst case.
  STUDIO_READ_TIMEOUT = 1800
  # runner_concurrency's default when CANARY_STUDIO_CONCURRENCY is unset -
  # see that method for why this is no longer 1.
  DEFAULT_STUDIO_CONCURRENCY = 4

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
  # (2026-08-03): $0.14/MTok input, $0.28/MTok output. STUDIO_MODELS are
  # $0.00 - local serving on already-owned hardware has no per-token
  # metering, so their true marginal rate is zero, not merely cheap.
  # ARM_H_MODELS rows are the pinned endpoint's own "prompt"/"completion"
  # figures (2026-08-04) from GET /models/<id>/endpoints, i.e. the
  # SiliconFlow (six models) or DeepInfra (nemotron-3-super-120b-a12b) row
  # specifically, not the model's cheapest or default-routed endpoint.
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
    "accounts/fireworks/models/deepseek-v4-flash" => {input_token_price: 0.14 / 1_000_000, output_token_price: 0.28 / 1_000_000},
    "qwen3.6-35b-a3b-4bit" => {input_token_price: 0.0, output_token_price: 0.0},
    "qwen3.6-35b-a3b-8bit" => {input_token_price: 0.0, output_token_price: 0.0},
    "qwen3-27b-optiq" => {input_token_price: 0.0, output_token_price: 0.0},
    "qwen3-122b-a10b" => {input_token_price: 0.0, output_token_price: 0.0},
    "nemotron-3-super" => {input_token_price: 0.0, output_token_price: 0.0},
    "qwen3.8-27b-mxfp8-concurrent4" => {input_token_price: 0.0, output_token_price: 0.0},
    "qwen3.8-27b-mxfp8-concurrent1" => {input_token_price: 0.0, output_token_price: 0.0},
    "qwen/qwen3.6-27b" => {input_token_price: 0.0000003, output_token_price: 0.0000032},
    "qwen/qwen3.6-35b-a3b" => {input_token_price: 0.0000002, output_token_price: 0.0000016},
    "google/gemma-4-26b-a4b-it" => {input_token_price: 0.00000012, output_token_price: 0.0000004},
    "google/gemma-4-31b-it" => {input_token_price: 0.00000013, output_token_price: 0.0000004},
    "openai/gpt-oss-120b" => {input_token_price: 0.00000005, output_token_price: 0.00000045},
    "qwen/qwen3.5-122b-a10b" => {input_token_price: 0.00000026, output_token_price: 0.00000208},
    "nvidia/nemotron-3-super-120b-a12b" => {input_token_price: 0.000000085, output_token_price: 0.0000004}
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
  #
  # I29 Arm H: openai/gpt-oss-120b (GET /models "reasoning":
  # {"mandatory": true, "supported_efforts": ["high","medium","low"]}) and
  # nvidia/nemotron-3-super-120b-a12b ("reasoning": {"default_enabled":
  # true, "supported_efforts": ["medium","low"]}) both enumerate "low" as a
  # supported effort live (2026-08-04), same OpenRouter unified mechanism
  # as above - the lowest effort that still leaves room for visible text
  # under SWEEP_MAX_TOKENS. The other five Arm H models are left out here
  # deliberately per the frozen pin table's own reasoning-class split.
  THINKING_EFFORT = {
    "deepseek/deepseek-v4-flash" => {reasoning: {effort: "low"}},
    "deepseek/deepseek-v4-pro" => {reasoning: {effort: "low"}},
    "moonshotai/kimi-k3" => {reasoning: {effort: "low"}},
    "moonshotai/kimi-k2.7-code" => {reasoning: {effort: "low"}},
    "qwen/qwen3.7-max" => {reasoning: {effort: "low"}},
    "z-ai/glm-5.2" => {reasoning: {effort: "low"}},
    "accounts/fireworks/models/deepseek-v4-flash" => {reasoning_effort: "low"},
    "openai/gpt-oss-120b" => {reasoning: {effort: "low"}},
    "nvidia/nemotron-3-super-120b-a12b" => {reasoning: {effort: "low"}},
    # Two measured operating points over the same checkpoint, kept side by
    # side for head-to-head comparison rather than one superseding the
    # other - the human call after both were scored was to keep both
    # regardless of which came out ahead.
    #
    # concurrent4 (batch point, drafter detached, max_num_seqs: 4): the
    # registry entry launches this engine with its own thinking_budget (512,
    # gateway lane), which forces the model out of its reasoning block and
    # into the answer server-side - measured finish_reason "stop" with a
    # complete solution at every budget tried (256/512/1024/2048). That
    # budget is mutually exclusive with speculative decoding in the server,
    # which concurrent4 also has detached, so the bound is enforced upstream
    # of this request either way. Left as an explicit empty fragment, not a
    # missing key, so this stays a documented no-op rather than an
    # accidental one.
    #
    # concurrent1 (interactive point, speculative drafter attached,
    # max_num_seqs: 1): its registry sibling cannot accept a thinking_budget
    # at all - the server raises per request when both a drafter and a
    # thinking budget are present - so request-side suppression
    # (reasoning_effort: "none") is the only bound available on this arm.
    # Measured live 2026-08-15 with thinking left on: the model ran out the
    # full 16_384-token budget rummaging over what the withheld tests might
    # assert and returned content: null. reasoning_effort: "none" is what
    # produced the committed results/run-20260815T215441Z/ arm (combined
    # pass rate 0.8636, 0 runaways) - dropping or approximating this
    # fragment measures a different arm than the one that's committed.
    "qwen3.8-27b-mxfp8-concurrent4" => {},
    "qwen3.8-27b-mxfp8-concurrent1" => {reasoning_effort: "none"}
  }.freeze

  # I26 (I25 F4): eval_sweep.rb never pinned OpenRouter routing, so every
  # "OR arm" was a multi-backend blend across whatever backend OpenRouter's
  # load balancer picked that call. Pins every :openrouter model (see
  # MODEL_PROVIDERS) to the one endpoint tag the architect chose 2026-08-04
  # from the seventh artifact's completions.jsonl modal-backend counts,
  # joined against the live GET /models/<id>/endpoints tables - every tag
  # below verified present live. The Fireworks-direct model
  # (accounts/fireworks/models/deepseek-v4-flash) is deliberately absent:
  # it hits a different API entirely and must never receive an OpenRouter
  # routing field.
  #
  # I29 Arm H: the seven R12 phase 1 hosted ids, pinned per the frozen
  # table the architect set this session - SiliconFlow fp8 for six models
  # (nemotron-3-super-120b-a12b's only non-fp4 SiliconFlow-class route is
  # DeepInfra bf16 instead). Every tag verified present live against GET
  # /models/<id>/endpoints, 2026-08-04.
  PROVIDER_PINS = {
    "deepseek/deepseek-v4-flash" => "alibaba/fp8",
    "deepseek/deepseek-v4-pro" => "alibaba/fp8",
    "moonshotai/kimi-k3" => "baseten/fp8",
    "moonshotai/kimi-k2.7-code" => "coreweave/int4",
    "qwen/qwen3-coder-plus" => "alibaba/fp8",
    "qwen/qwen3.7-max" => "alibaba/fp8",
    "z-ai/glm-5.2" => "baseten/fp8",
    "qwen/qwen3.6-27b" => "siliconflow/fp8",
    "qwen/qwen3.6-35b-a3b" => "siliconflow/fp8",
    "google/gemma-4-26b-a4b-it" => "siliconflow/fp8",
    "google/gemma-4-31b-it" => "siliconflow/fp8",
    "openai/gpt-oss-120b" => "siliconflow/fp8",
    "qwen/qwen3.5-122b-a10b" => "siliconflow/fp8",
    "nvidia/nemotron-3-super-120b-a12b" => "deepinfra/bf16"
  }.freeze

  # The eval's own token budget, passed explicitly to every provider
  # .build_provider constructs below - the library defaults
  # (Providers::Anthropic::DEFAULT_MAX_TOKENS,
  # Providers::OpenAICompat::DEFAULT_MAX_TOKENS) stay 4096, since a sweep-
  # wide budget belongs in the sweep's own config, not in a default every
  # other caller inherits. Raised from 4096: I20 measured 20 of 54
  # kimi-k2.7-code hidden records truncated at the 4096 cap with zero
  # visible text - reasoning burn eating the whole budget before any answer
  # appeared. 16_384 is the smallest power-of-two step (4x) that turns that
  # observed burn into headroom.
  SWEEP_MAX_TOKENS = 16_384

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
      env_key = PROVIDER_ENV_KEYS[kind]
      next unless env_key

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

  # I24: narrows both arms to a single caller-chosen model (bin/eval_sweep.rb
  # MODEL_ID), or - with no model given - the full configured sets minus
  # CANARY_SWEEP_SKIP, unchanged from before this method existed. Aborts
  # before any env/key demand on an unknown model, naming MODEL_PROVIDERS'
  # keys as the authority on what's known. Returns [hidden_models,
  # visible_models, skip] so .run can both derive the spend cap from what
  # will actually run and print what CANARY_SWEEP_SKIP dropped.
  #
  # I27: a single-model selection also matches STUDIO_MODELS (hidden-only,
  # see that constant) - HIDDEN_MODELS itself stays untouched so the
  # no-model default path a few lines below never picks one up (AC1).
  # VISIBLE_MODELS & [model] already excludes every studio alias with no
  # special-casing needed, since VISIBLE_MODELS only ever lists the two
  # Anthropic anchors.
  #
  # I29: ARM_H_MODELS joins the same union on the same terms as
  # STUDIO_MODELS - hidden-only, selectable-not-default (AC1).
  def self.select_models(model)
    if model
      unless MODEL_PROVIDERS.key?(model)
        abort "unknown model #{model.inspect} - known models: #{MODEL_PROVIDERS.keys.join(', ')}"
      end
      return [(HIDDEN_MODELS + STUDIO_MODELS + ARM_H_MODELS) & [model], VISIBLE_MODELS & [model], []]
    end

    skip = skipped_models
    [HIDDEN_MODELS - skip, VISIBLE_MODELS - skip, skip]
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
      Canary::Providers::Anthropic.new(max_tokens: SWEEP_MAX_TOKENS)
    when :openrouter, :fireworks
      extra_body_by_model = models.to_h { |model| [model, extra_body_for(model)] }
      Canary::Providers::OpenAICompat.new(
        base_url: PROVIDER_BASE_URLS.fetch(kind), api_key: ENV.fetch(PROVIDER_ENV_KEYS.fetch(kind)),
        max_tokens: SWEEP_MAX_TOKENS, extra_body_by_model: extra_body_by_model
      )
    when :studio
      extra_body_by_model = models.to_h { |model| [model, extra_body_for(model)] }
      Canary::Providers::OpenAICompat.new(
        base_url: PROVIDER_BASE_URLS.fetch(kind), api_key: STUDIO_API_KEY,
        max_tokens: SWEEP_MAX_TOKENS, read_timeout: STUDIO_READ_TIMEOUT,
        extra_body_by_model: extra_body_by_model
      )
    else
      raise ArgumentError, "unknown provider kind: #{kind.inspect}"
    end
  end

  # THINKING_EFFORT's reasoning/reasoning_effort key and PROVIDER_PINS'
  # provider key never collide (disjoint top-level keys), so a shallow
  # merge suffices - no deep-merge helper needed for two flat fragments.
  def self.extra_body_for(model)
    THINKING_EFFORT.fetch(model, {}).merge(provider_pin_fragment(model))
  end

  def self.provider_pin_fragment(model)
    tag = PROVIDER_PINS[model]
    return {} unless tag

    {provider: {order: [tag], allow_fallbacks: false}}
  end

  # One fresh directory per run, so a rerun supersedes rather than
  # overwrites - see the module comment.
  def self.new_run_dir
    File.join(RESULTS_DIR, Time.now.utc.strftime("run-%Y%m%dT%H%M%SZ"))
  end

  # Replaces a hand-maintained SPEND_CAP_DOLLARS constant with a derivation
  # run fresh at every startup (Standing rule 5: the number carries its
  # source, printed line by line by .run below, rather than living in a
  # comment that has to be re-derived by hand every time the corpus, model
  # set, or token budget changes). Worst case, per HIDDEN_MODELS/
  # VISIBLE_MODELS as configured (not narrowed by any runtime
  # CANARY_SWEEP_SKIP - a worst case assumes nothing gets skipped): each
  # model's total call count (tasks_count x HIDDEN_K if it's in the hidden
  # arm, plus tasks_count x VISIBLE_K if it's in the visible arm) x
  # max_tokens x that model's PRICE_TABLE output price, input cost ignored
  # as every prior derivation of this cap did. The cap is 3x that sum,
  # rounded up to the dollar - the same order of headroom every prior
  # version of this cap held.
  def self.spend_cap_derivation(tasks_count:, hidden_models: HIDDEN_MODELS, visible_models: VISIBLE_MODELS, price_table: PRICE_TABLE, max_tokens: SWEEP_MAX_TOKENS)
    lines = []
    worst_case = (hidden_models + visible_models).uniq.sum do |model|
      calls = (hidden_models.include?(model) ? tasks_count * HIDDEN_K : 0) +
              (visible_models.include?(model) ? tasks_count * VISIBLE_K : 0)
      rate = price_table.fetch(model).fetch(:output_token_price)
      cost = calls * max_tokens * rate
      lines << format("  %-45s %4d calls x %d x $%.8f = $%.4f", model, calls, max_tokens, rate, cost)
      cost
    end

    cap = (worst_case * 3).ceil
    lines << format("  worst case sum: $%.4f", worst_case)
    lines << format("  cap (3x worst case, rounded up): $%d", cap)
    [cap, lines]
  end

  def self.run
    model = ARGV.first
    hidden_models, visible_models, skip = select_models(model)
    puts "selected model: #{model}" if model
    puts "CANARY_SWEEP_SKIP dropped: #{skip.join(', ')}" unless skip.empty?

    load_env!(models: hidden_models + visible_models)

    tasks = Canary::TaskRepo.all
    total_calls = (tasks.size * HIDDEN_K * hidden_models.size) + (tasks.size * VISIBLE_K * visible_models.size)
    budget = Canary::Sampler::Budget.new(max_samples: total_calls)

    cap, cap_lines = spend_cap_derivation(
      tasks_count: tasks.size, hidden_models: hidden_models, visible_models: visible_models
    )
    puts "spend guard cap derivation:"
    cap_lines.each { |line| puts line }
    spend_guard = Canary::Sampler::SpendGuard.new(max_dollars: cap, price_table: PRICE_TABLE)

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

    puts "spend guard cap: $#{cap}"
    puts "budget cap: #{total_calls} samples"
    puts "hidden arm: #{tasks.size} tasks x k=#{HIDDEN_K} x #{hidden_models.join(', ')}"
    hidden = run_arm(samplers: samplers, tasks: tasks, models: hidden_models, k: HIDDEN_K, grader: false, &append_record)

    puts "grader-visible arm: #{tasks.size} tasks x k=#{VISIBLE_K} x #{visible_models.join(', ')}"
    visible = run_arm(samplers: samplers, tasks: tasks, models: visible_models, k: VISIBLE_K, grader: true, &append_record)

    records = hidden + visible
    report_spend(records)
    write_summary(records, run_dir, cap_lines)
    puts "wrote #{records.size} records to #{records_path}"
    puts "wrote completions to #{completions_path}"
    records_path
  end

  # Groups +models+ by declared provider and runs each group through its
  # own Runner instance against the matching pre-built sampler - the
  # split is invisible to the caller (still one flat Array of Records
  # back), and a single-provider model set (today's config) collapses to
  # exactly the one runner.call the pre-multi-provider code made.
  #
  # I28 pinned :studio's Runner to concurrency: 1, on a finding that the
  # gateway 502'd (upstream EOFError) on any second in-flight request. That
  # finding is stale: canary's workaround landed 2026-08-05, and the
  # gateway's "no-more-wedging: single-flight swap + engine liveness" merged
  # 2026-08-06 - one day later. Live re-measurement through the TLS edge on
  # 2026-08-15 found 2, 4 and 8 concurrent completions all returned 200
  # (4.92s / 2.33s / 3.10s total respectively, batched rather than
  # serialized) - see runner_concurrency for the resulting knob.
  def self.run_arm(samplers:, tasks:, models:, k:, grader:, &on_record)
    models.group_by { |model| MODEL_PROVIDERS.fetch(model) }.flat_map do |kind, models_for_kind|
      runner = Canary::Eval::Runner.new(sampler: samplers.fetch(kind), concurrency: runner_concurrency(kind))
      runner.call(entries: tasks, models: models_for_kind, k: k, grader: grader, &on_record)
    end
  end

  # :studio's concurrency is a configurable knob, not Runner's own
  # DEFAULT_CONCURRENCY every hosted kind gets (see run_arm for why 1 is no
  # longer required) - CANARY_STUDIO_CONCURRENCY overrides
  # DEFAULT_STUDIO_CONCURRENCY the same way CANARY_SWEEP_SKIP overrides the
  # model set (see .skipped_models), read fresh on every call rather than
  # baked into a constant at load time.
  def self.studio_concurrency
    Integer(ENV["CANARY_STUDIO_CONCURRENCY"] || DEFAULT_STUDIO_CONCURRENCY)
  end

  def self.runner_concurrency(kind)
    kind == :studio ? studio_concurrency : Canary::Eval::Runner::DEFAULT_CONCURRENCY
  end

  def self.record_cost(record)
    return 0.0 unless record.input_tokens && record.output_tokens

    rate = PRICE_TABLE.fetch(record.model)
    (record.input_tokens * rate[:input_token_price]) + (record.output_tokens * rate[:output_token_price])
  end

  def self.total_spend(records)
    records.sum { |record| record_cost(record) }
  end

  def self.report_spend(records)
    tripped = records.any? { |record| record.non_score_reason == :spend_exceeded }
    puts "spend guard tripped: #{tripped}"
    puts format("actual spend (from recorded token usage x price table): $%.4f", total_spend(records))
  end

  # AC4 (I21 F3 correction): summary.md carries the same actual-spend figure
  # and cap-derivation lines the runner already prints to stdout, so a gate
  # can point at the artifact rather than a run's own terminal output.
  #
  # I26 (R11(b) ruling): a model/mode section pools authored and sourced
  # tasks into one pass rate no longer - each section splits into an
  # authored sub-report and a sourced sub-report, provenance looked up per
  # record from Canary::TaskRepo.all by task_name. A task_name absent from
  # the repo raises (Hash#fetch) rather than silently falling into either
  # bucket.
  def self.write_summary(records, run_dir, cap_lines)
    lines = ["# Canary eval sweep", ""]
    lines << format("actual spend (from recorded token usage x price table): $%.4f", total_spend(records))
    lines << ""
    lines << "spend guard cap derivation:"
    lines.concat(cap_lines)
    lines << ""
    provenance_by_task = Canary::TaskRepo.all.to_h { |entry| [entry.name, entry.provenance] }
    records.group_by { |record| [record.model, record.render_mode] }.sort.each do |(model, mode), arm_records|
      lines.concat(arm_section(model, mode, arm_records, provenance_by_task))
    end

    path = File.join(run_dir, "summary.md")
    File.write(path, lines.join("\n"))
    puts "wrote summary to #{path}"
    path
  end

  def self.arm_section(model, mode, arm_records, provenance_by_task)
    lines = ["## #{model} / #{mode}", ""]
    %w[authored sourced].each do |provenance|
      provenance_records = arm_records.select { |record| provenance_by_task.fetch(record.task_name) == provenance }
      lines.concat(provenance_section(provenance, provenance_records))
    end
    lines
  end

  def self.provenance_section(provenance, provenance_records)
    k = provenance_records.group_by(&:task_name).values.map(&:size).max
    report = Canary::Eval::Report.new(provenance_records)

    lines = ["### #{provenance}", ""]
    lines << "- scored: #{report.scored_count}, non_score: #{report.non_score_count}"
    lines << "- non_scores_by_reason: #{report.non_scores_by_reason}"
    lines << "- pass_at_1: #{report.pass_at_1.inspect} (tasks_counted: #{report.tasks_counted(1)})"
    lines << "- pass_at_#{k}: #{report.pass_at_k(k).inspect} (tasks_counted: #{report.tasks_counted(k)})" if k && k > 1
    lines << ""
    lines.concat(task_table(provenance_records))
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
