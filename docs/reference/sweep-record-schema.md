# Reference: sweep record schema

`Canary::Eval::Record` (`lib/canary/eval/record.rb`) is one row per (task,
model, sample index): whatever `Canary::Eval::Runner` learned trying to get
one graded answer out of one model on one task. One JSON line per record in
a sweep's `sweep.jsonl` (see
[`../how-to/run-a-sweep.md`](../how-to/run-a-sweep.md)).

`schema_version` is currently `1` (`Canary::Eval::Runner::SCHEMA_VERSION`) —
a plain field, not inferred from shape, so a future format change can tell
old records apart from new ones on disk.

## Fields

| field | type | always present | meaning |
|---|---|---|---|
| `schema_version` | Integer | yes | record format version. |
| `task_name` | String | yes | matches a `Canary::TaskRepo::Entry#name`. |
| `model` | String | yes | the model identifier sampled. |
| `sample_index` | Integer | yes | which of the `k` samples for this (task, model) pair. |
| `render_mode` | `:hidden` or `:grader_visible` | yes | which `Canary::Prompt.render` mode produced the prompt. |
| `scored` | Boolean | yes | **the load-bearing field.** `false` means the harness never got to judge this sample — a refusal, a truncated response, an unextractable answer, a budget/spend guard trip, a transport error. A `scored: false` record MUST NOT carry a `passed` verdict. |
| `non_score_reason` | Symbol or nil | when `scored: false` | one of `:refusal`, `:truncated`, `:premature_stop`, `:transport_error`, `:budget_exhausted`, `:spend_exceeded`, `:extractor_refusal`, `:unexpected_finish_reason`, `:empty_completion`. Never set when `scored: true`. |
| `passed` | Boolean or nil | when `scored: true` | whether the rollout succeeded. |
| `prefilter_clean` | Boolean or nil | when scored, or on a prefilter-truncation non-score | `Canary::Prefilter::Report#clean?` for the extracted code. |
| `rollout_outcome` | Symbol or nil | when scored | the underlying `Canary::RolloutResult#outcome` (`:ok`, `:error`, `:crash`, `:timeout`, `:invalid`), when a rollout actually ran. |
| `passed_examples` | Integer or nil | when a rollout ran | `RolloutResult#passed`. |
| `total_examples` | Integer or nil | when a rollout ran | `RolloutResult#total`. |
| `coverage_fraction` | Float or nil | when a rollout ran with coverage | fraction of the solution file's lines with positive coverage counts; `nil` if no coverage data. |
| `extractor_outcome` | Symbol or nil | when the extractor ran | `:ok`, or a refusal outcome (`:no_fenced_code`, `:no_ruby_fence`) from `Canary::Extractor`. |
| `stop_reason` | value or nil | usually | the provider's own stop reason (e.g. `:end_turn`, `:max_tokens`, `:refusal`), read off the raw response. Present even on many non-score records — this is what makes a token-limit truncation auditable on an otherwise-scored record (see the README's sampler note). |
| `input_tokens` / `output_tokens` | Integer or nil | when usage was reported | token counts off the provider's own `usage` field. |

## Non-score reasons

From `Canary::Sampler` (`lib/canary/sampler.rb`) and
`Canary::Providers::Anthropic`/`OpenAICompat`:

- `:budget_exhausted` — the sampler's request-count budget was already
  spent before this sample was attempted; never dispatched.
- `:spend_exceeded` — the dollar spend guard had already tripped before
  this sample was attempted; never dispatched.
- `:refusal` — the provider's own content-refusal stop reason.
- `:truncated` — either the provider cut the response off at its token
  limit *and* the extracted code still ends mid-construct (a parse error
  anchored at end-of-source, per `Canary::Prefilter::Report#truncated`), or
  the response was truncated before any usable text came back. A truncated
  response whose extracted code *does* parse cleanly is scored normally
  instead — see `Canary::Eval::Runner#verified_record`. Requires
  provider-evidenced cutoff evidence: the sample's `stop_reason` must be one
  of `Canary::Eval::Runner::CUTOFF_STOP_REASONS` (`:max_tokens` or
  `:length`).
- `:premature_stop` — the extracted code ends mid-construct (the same
  EOF-anchored `Canary::Prefilter::Report#truncated` parse failure as
  `:truncated`), but the sample's `stop_reason` does *not* evidence a
  provider-side cutoff — the model stopped generating on its own and simply
  wrote code that doesn't parse, rather than being cut off by a token limit
  (`Canary::Eval::Runner#non_score_reason_for`).
- `:unexpected_finish_reason` — `OpenAICompat`-only: the response's
  `finish_reason` was absent, `"tool_calls"`, or any string other than
  `"stop"`, `"length"`, or `"content_filter"`.
- `:empty_completion` — `OpenAICompat`-only: `finish_reason` was `"stop"`
  but the message content was nil or empty.

From `Canary::Eval::Runner`:

- `:extractor_refusal` — the model answered, but
  `Canary::Extractor` found no fenced Ruby to grade (`extractor_outcome`
  distinguishes "no fence at all" from "a fence, wrong language").

`Canary::Eval::Report` (`lib/canary/eval/report.rb`) is the aggregator built
on top of a set of records: it keeps every non-score out of a rate's
denominator (`non_scores_by_reason`, `scored_count`) and computes `pass@k`
via the unbiased Chen et al. 2021 estimator, returning `nil` rather than
`0.0` when there are zero scored samples for a task.
