# canary docs

Organised [diátaxis](https://diataxis.fr)-style: tutorial and how-to are
task-oriented, reference and explanation are information-oriented. If you
arrived from the Canary Register, start with
[methodology](explanation/methodology.md) and
[the results layout](reference/results-layout.md).

## Tutorial

- [Install, run the suite, grade one rollout](tutorial.md) — from a clean
  checkout to watching `Canary::Verifier` grade a submission, offline.

## How-to

- [Run a sweep](how-to/run-a-sweep.md) — `bin/eval_sweep.rb`: the
  `CANARY_LIVE` gate, the four model lists and four provider kinds, the
  knobs that shape a run, and what one run writes.
- [Rescore a run](how-to/rescore-a-run.md) — `bin/rescore.rb`: re-grade
  committed runs against the current extractor without buying a sample.
- [Author a task](how-to/author-a-task.md) — the per-file contract for a
  new `tasks/<name>/` directory and the statement-writing rules.
- [Run the server](how-to/run-the-server.md) — boot `bin/canary-server`
  and call `POST /v1/rollouts` or `POST /v1/eval`.
- [Run the tool loop](how-to/run-the-tool-loop.md) — `bin/canary-tool-loop`:
  a chat model calls `ruby_eval`/`run_tests` as tools against a running
  `bin/canary-server` and loops to a final answer.
- [Measure turn latency](how-to/measure-turn-latency.md) —
  `bin/canary-loop-bench`: several concurrent `Canary::ToolLoop`
  conversations against one model, per-turn latency and the gateway's
  prefix-cache behaviour under interleaved load.

## Reference

- [Results layout](reference/results-layout.md) — what is in a
  `results/run-*/` directory, the three record schemas and which runs
  carry which, rescore sidecars, and `run_config.json`.
- [Sweep record schema](reference/sweep-record-schema.md) — every
  `Canary::Eval::Record` field and every non-score reason.
- [`meta.yml` keys](reference/meta-yml.md)
- [Wire protocol](reference/wire-protocol.md) — the `POST /v1/rollouts`
  and `POST /v1/eval` request and response shapes.
- [Public API map](reference/public-api.md) — every constant
  `require "canary"` loads, one line each.

## Explanation

- [Methodology](explanation/methodology.md) — how the register's pass
  rates, intervals, throughput and memory figures are derived, what pools
  with what, and what the instrument cannot see.
- [The thesis](explanation/thesis.md) — why Ruby.
- [Contamination](CONTAMINATION.md) — provenance, held-out posture, which
  tasks have crossed a hosted endpoint, and the reasoning traces the
  results carry.
- [Threat boundary](explanation/threat-boundary.md) — the tamper vectors
  the sandbox does not defend against, and why.
