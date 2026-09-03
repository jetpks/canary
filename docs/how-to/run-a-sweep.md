# How-to: run a sweep

`bin/eval_sweep.rb` runs every task in `Canary::TaskRepo.all` against a
set of models, three samples per task, and writes the results under
`results/run-<timestamp>/`. Against a hosted provider it spends real
money. Against a local model it ties up the inference box for anywhere
from ten minutes to several hours. Read this page before running it live.

**Presented, not executed.** The invocations below are shown for
reference; none is run as part of producing this page.

## It is opt-in

```ruby
abort "CANARY_LIVE=1 is required to run the live sweep" unless ENV["CANARY_LIVE"]
```

Nothing in the script makes a network call, reads a credential, or spends
a cent unless `CANARY_LIVE=1` is set. With it set, `EvalSweep.load_env!`
reads a gitignored `.env` in the repo root if one exists and demands only
the keys the selected models need (`EvalSweep::PROVIDER_ENV_KEYS`). Copy
`.env.example` to start one.

## Model lists

Four lists in `bin/eval_sweep.rb`. Only the first two run by default.

| constant | runs | what |
|---|---|---|
| `HIDDEN_MODELS` | bare invocation, hidden arm, `k=HIDDEN_K` (3) | ten current-generation hosted models: two Anthropic anchors, seven via OpenRouter, one via Fireworks |
| `VISIBLE_MODELS` | bare invocation, grader-visible arm, `k=VISIBLE_K` (1) | the two Anthropic anchors only |
| `STUDIO_MODELS` | only when named | thirty aliases served locally behind an OpenAI-compatible gateway on owned hardware, $0 marginal cost |
| `ARM_H_MODELS` | only when named | seven hosted consumer-class open-weight models, each pinned to one OpenRouter endpoint |

`STUDIO_MODELS` and `ARM_H_MODELS` stay out of `HIDDEN_MODELS` on purpose:
a bare invocation is always the hosted-only sweep, and a local or Arm H
model runs only when named.

The full hosted sweep, every key demanded:

```console
CANARY_LIVE=1 bundle exec ruby bin/eval_sweep.rb
```

One model. The positional argument narrows both arms to that model, so
only its provider's key is demanded, and an OpenRouter or local model runs
hidden-only because neither is in `VISIBLE_MODELS`:

```console
CANARY_LIVE=1 bundle exec ruby bin/eval_sweep.rb qwen/qwen3-coder-plus
CANARY_LIVE=1 CANARY_STUDIO_CONCURRENCY=1 bundle exec ruby bin/eval_sweep.rb qwen3.8-27b-mxfp4
```

`EvalSweep::MODEL_PROVIDERS` is the authority on which ids exist. An id
missing from it aborts before any env or key demand, naming the ones it
knows. Adding a model means adding it to a list, to `MODEL_PROVIDERS`, to
`PRICE_TABLE`, and, if it reasons, to `THINKING_EFFORT`; the offline test
below catches a missing entry.

To drop a model from the full sweep without editing the file:

```console
CANARY_LIVE=1 CANARY_SWEEP_SKIP="qwen/qwen3-coder-plus,z-ai/glm-5.2" bundle exec ruby bin/eval_sweep.rb
```

It has no effect when a model is named positionally.

## Providers

`MODEL_PROVIDERS` maps each model to one of four kinds. A model missing
from it is a configuration error, not a silent default.

| kind | endpoint | credential |
|---|---|---|
| `:anthropic` | the `anthropic` gem | `ANTHROPIC_API_KEY` |
| `:openrouter` | OpenRouter, via `Providers::OpenAICompat` | `OPENROUTER_API_KEY` |
| `:fireworks` | Fireworks, via `Providers::OpenAICompat` | `FIREWORKS_API_KEY` |
| `:studio` | a local gateway, via `Providers::OpenAICompat` | none |

`:studio` gets a 1800 s read timeout instead of the 60 s default, because
a backend that loads a model into memory before answering needs an order
of magnitude more headroom.

Three per-model tables shape the request body:

- **`PROVIDER_PINS`** pins every OpenRouter model to one endpoint tag with
  `allow_fallbacks: false`. Without a pin an "OpenRouter arm" is a blend of
  whatever backend the load balancer picked per call, which is not one
  measurement.
- **`THINKING_EFFORT`** carries each model's reasoning setting in its own
  backend's vocabulary: OpenRouter takes `reasoning: {effort:}`, Fireworks
  a `reasoning_effort` string, the local engines `reasoning_effort` too.
  Every local arm carries `"none"` except `nemotron-3-super-low`, the one
  arm deliberately bought with reasoning on as a control. Each entry's
  comment records what was measured to justify it; on at least one model
  (`muse-glimmer-30b`) `"none"` is a suggestion the template partly
  ignores, and the comment says so.
- **`PRICE_TABLE`**, $/token, used for the spend cap and the actual-spend
  line. Local models price at $0.00 because owned hardware has no
  per-token metering.

All of it is written into the run's `run_config.json`, so a run states
its own parameters.

## Knobs

| variable | default | effect |
|---|---|---|
| `SWEEP_MAX_TOKENS` | 4096 | the per-request token budget. Lowered from 16 384 on 2026-09-01 once the stated output contract collapsed answer length (schema-3 passing answers: median 102 tokens, p99 3 447). Override for one run to re-buy an arm at the old cap. The applied value is recorded in `run_config.json`; runs bought at different caps are not strictly comparable. |
| `CANARY_STUDIO_CONCURRENCY` | 4 | in-flight requests against a `:studio` model. Hosted kinds use `Canary::Eval::Runner::DEFAULT_CONCURRENCY` (5). Every register run was bought at 1 so that per-sample wall clock is a serial measurement; use 1 when timing matters. |
| `CANARY_SWEEP_SKIP` | empty | comma-separated ids dropped from the full sweep. |

## Sampling

`Providers::OpenAICompat` states `temperature` (1.0) and a seed on every
request instead of inheriting the server's defaults, because "the server
default" is not one behaviour: hosted endpoints sample, a local mlx server
decodes greedily. A sweep against a greedy backend that sent neither was a
`k=1` sweep billed three times, and the runs before 2026-08-27 were
exactly that (schema 1; see
[results layout](../reference/results-layout.md)).

The seed is derived from the prompt *and* the sample index
(`OpenAICompat.seed_for`). A seed from the index alone replays the same
random draw sequence across every task at that index and correlates the
samples instead of making them independent. Digesting the prompt keeps a
re-run reproducible while decorrelating the tasks.

`Canary::Eval::Runner` schedules **sample-major**: every task's sample 0
before any task's sample 1. A batching engine given three copies of one
prompt in one batch returns one answer three times however the seeds
differ; interleaving the tasks means the requests in flight are different
prompts.

## Spend

Before any call the script derives a spend cap from the models that will
actually run (3× the worst case if every call maxed its token budget,
printed line by line) and wires it into a `Canary::Sampler::SpendGuard`
that stops the run once recorded spend exceeds it. Actual spend, from each
record's token usage against `PRICE_TABLE`, is printed at the end and
written to `summary.md`. The guard bounds a runaway; it does not shrink a
normal run.

## What one run writes

A fresh `results/run-<timestamp>/`, never overwriting an earlier one:

- `run_config.json` — schema version, task count, `k`, `max_tokens`,
  temperature, seed derivation, per-model concurrency, provider and
  extra request fields, and the full system prompt.
- `sweep.jsonl` — one `Canary::Eval::Record` per sample
  ([schema](../reference/sweep-record-schema.md)).
- `completions.jsonl` — per sample, the exact request body sent and the
  raw response received, written before the record it produced.
- `summary.md` — spend, the cap derivation, the run config, and one
  section per (model, render mode) split into authored and sourced
  sub-reports with per-task pass counts and wall-clock lines.

Both `.jsonl` files are appended as each sample lands, not batched at the
end: an exception on call 90 must not cost the 89 samples already paid
for. A run that dies part-way is still a valid partial run.

[Results layout](../reference/results-layout.md) covers the directory in
full, including the rescore sidecars a later
[`bin/rescore.rb`](rescore-a-run.md) may add.

## Prove the shape offline

`test/canary/eval/eval_sweep_test.rb` exercises the directory layout,
provider and price-table configuration, model selection, concurrency
resolution, run config, and the spend-cap math with no `CANARY_LIVE` and
no network:

```console
bundle exec ruby -Ilib -Itest test/canary/eval/eval_sweep_test.rb
```

```text
Finished in 0.245319s, 199.7399 runs/s, 3892.8905 assertions/s.

49 runs, 955 assertions, 0 failures, 0 errors, 0 skips
```

Run it after touching `bin/eval_sweep.rb`. It catches a model missing a
provider or price entry before a live run would.
