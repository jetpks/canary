# canary docs

Organized [diátaxis](https://diataxis.fr)-style: tutorial and how-to are
task-oriented, reference and explanation are information-oriented. Start with
the tutorial if you're new here.

## Tutorial

- [Install, run the suite, run one rollout](tutorial.md) — the shortest path
  from a clean checkout to watching `Canary::Verifier` actually grade a
  submission, in-process, offline.

## How-to

- [Author a task](how-to/author-a-task.md) — the full per-file contract for
  a new `tasks/<name>/` directory: `meta.yml`, `solution.rb`, `grader.rb`,
  `broken/*.rb`, and the statement-writing rules the grader depends on.
- [Run a sweep](how-to/run-a-sweep.md) — `bin/eval_sweep.rb`, the
  `CANARY_LIVE` opt-in gate, and the offline test that proves its shape
  without spending anything.
- [Run the server](how-to/run-the-server.md) — boot `bin/canary-server` and
  call `POST /v1/rollouts` or `POST /v1/eval` over a real loopback socket.
- [Run the tool loop](how-to/run-the-tool-loop.md) — `bin/canary-tool-loop`,
  the first end-to-end agentic loop on this stack: a chat model calls
  `ruby_eval`/`run_tests` as tools against a real `bin/canary-server` and
  loops to a final answer.
- [Measure turn latency](how-to/measure-turn-latency.md) — `bin/canary-loop-bench`,
  several concurrent `Canary::ToolLoop` conversations against one model,
  measuring per-turn latency and the studio gateway's prefix-cache behavior
  under interleaved load.

## Reference

- [`meta.yml` keys](reference/meta-yml.md)
- [Sweep record schema](reference/sweep-record-schema.md) — every
  `Canary::Eval::Record` field, including the non-score reasons.
- [Wire protocol](reference/wire-protocol.md) — the `POST /v1/rollouts` and
  `POST /v1/eval` request/response shapes.
- [Public API map](reference/public-api.md) — every class `require "canary"`
  loads, one line each.

## Explanation

- [The thesis](explanation/thesis.md) — why Ruby, in more depth than the
  README.
- [Contamination](../docs/CONTAMINATION.md) — what this project can and
  cannot claim about whether the models it evaluates have seen this corpus
  before.
- [Threat boundary](explanation/threat-boundary.md) — the tamper taxonomy
  the sandbox does not defend against, and why.
