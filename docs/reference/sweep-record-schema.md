# Reference: sweep record schema

`Canary::Eval::Record` (`lib/canary/eval/record.rb`) is one row per (task,
model, sample index): whatever `Canary::Eval::Runner` learned trying to
get one graded answer out of one model on one task. One JSON line per
record in a run's `sweep.jsonl` (see
[results-layout.md](results-layout.md)).

`schema_version` is currently `3` (`Canary::Eval::Runner::SCHEMA_VERSION`).
It is a plain field, not inferred from shape, so a format change can tell
old records apart from new ones on disk. The three versions on disk are
different measurements, not one measurement with fields appended;
[results-layout.md](results-layout.md) §Three schemas says what changed
at each step and which runs carry which.

## Fields

| field | type | present | meaning |
|---|---|---|---|
| `schema_version` | Integer | always | record format version. |
| `task_name` | String | always | matches a `Canary::TaskRepo::Entry#name`. |
| `model` | String | always | the model id sampled, as passed to the provider. For local models this is the gateway alias, not the checkpoint. |
| `sample_index` | Integer | always | which of the `k` samples for this (task, model) pair. |
| `render_mode` | `"hidden"` or `"grader_visible"` | always | which `Canary::Prompt.render` mode produced the prompt. |
| `scored` | Boolean | always | **the load-bearing field.** `false` means the harness never got to judge this sample. A `scored: false` record never carries a `passed` verdict. |
| `non_score_reason` | String or null | when `scored: false` | one of the reasons below. Never set when `scored: true`. |
| `passed` | Boolean or null | when `scored: true` | whether the rollout passed the grader. A prefilter reject (code that does not parse) is `scored: true, passed: false`: the model's own code fell short. |
| `prefilter_clean` | Boolean or null | when scored, or on a truncation non-score | `Canary::Prefilter::Report#clean?` for the extracted code. |
| `rollout_outcome` | String or null | when a rollout ran | `Canary::RolloutResult#outcome`: `ok`, `error`, `crash`, `timeout`, `invalid`. |
| `passed_examples` / `total_examples` | Integer or null | when a rollout ran | grader example counts. |
| `coverage_fraction` | Float or null | when a rollout ran with coverage | fraction of the submission's lines with positive coverage counts. |
| `extractor_outcome` | String or null | when the extractor ran | how the answer was read; see below. |
| `stop_reason` | String or null | usually | the provider's own stop reason, normalised: `end_turn`, `max_tokens`, `refusal` from Anthropic; `stop`, `length`, `content_filter` from OpenAI-compatible endpoints. Present on non-score records too, which is what makes a truncation auditable. |
| `input_tokens` / `output_tokens` | Integer or null | when usage was reported | off the provider's `usage` field. `output_tokens` includes reasoning tokens where the provider counts them. |
| `sample_ms` | Integer or null | schema 2 and later | wall time for the whole attempt: render, provider round trip, and any queueing behind a busy engine. Stamped in the runner, not the provider, and set on every record including non-scored ones. |

## Extractor outcomes

`Canary::Extractor` reads the model's text and reports how:

| outcome | graded | meaning |
|---|---|---|
| `ok` | yes | the first fence tagged `ruby` or untagged was taken as the submission. |
| `bare_ruby` | yes | no fence anywhere; the whole answer parses as Ruby and defines a method, class or module. |
| `bare_malformed` | yes | no fence anywhere; the answer is not parseable Ruby. It is still graded, and fails at the prefilter, because a fenced answer that does not parse is graded that way too. |
| `no_ruby_fence` | no | the answer fenced something tagged for another language. |
| `no_fenced_code` | no | the answer is empty. |

The two bare outcomes were added on 2026-09-01. Runs before that recorded
every unfenced answer as `no_fenced_code`; [`bin/rescore.rb`](../how-to/rescore-a-run.md)
re-reads them under the current rule.

## Non-score reasons

Pre-flight, from `Canary::Sampler`; the sample was never dispatched:

- `budget_exhausted` — the request-count budget was already spent.
- `spend_exceeded` — the dollar guard had already tripped.

From the provider:

- `refusal` — the provider's own content-refusal stop reason, with no
  text to grade.
- `transport_error` — a non-2xx status, a timeout, a socket error, or an
  unparseable body.
- `unexpected_finish_reason` — OpenAI-compatible only: `finish_reason`
  absent, `"tool_calls"`, or anything other than `"stop"`, `"length"`,
  `"content_filter"`.
- `empty_completion` — OpenAI-compatible only: `finish_reason` was
  `"stop"` but the message content was empty.

From the runner, after the model answered:

- `extractor_refusal` — the extractor found nothing gradable;
  `extractor_outcome` says which shape.
- `truncated` — the extracted code ends mid-construct (a parse error
  anchored at end of input) *and* the provider evidenced a cutoff
  (`stop_reason` `max_tokens` or `length`). A cut-off response whose code
  still parses is scored normally, with the stop reason kept for audit.
- `premature_stop` — the code ends mid-construct but the provider
  reported a clean stop: the model stopped on its own and wrote code that
  does not parse.

## Aggregation

`Canary::Eval::Report` (`lib/canary/eval/report.rb`) aggregates a record
set. Its one rule: a non-score never enters a rate's denominator, and a
rate over zero scored records is `nil`, not `0.0`. `pass_at_k` is the
unbiased estimator from Chen et al. 2021, per task then averaged;
`pass_at_1` is the empirical per-task pass rate under that name.
`tasks_counted(k)` says how many tasks had at least `k` scored samples,
since the average silently drops the rest.

This is the reading `summary.md` prints. The Canary Register reports a
different one, pass rate on **all** samples with non-scores counted as
failures. [Methodology](../explanation/methodology.md) says why both
exist and when each is the right number.

Timing accessors (`timed_records`, `total_sample_ms`, `median_sample_ms`,
`seconds_per_task_passed`) read `sample_ms` over all records, scored or
not: a sample that burned four minutes and then failed to extract still
cost four minutes. Schema-1 records have no `sample_ms` and report no
timing rather than a wrong one.
