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
  call `POST /v1/rollouts` over a real loopback socket.

## Reference

- [`meta.yml` keys](reference/meta-yml.md)
- [Sweep record schema](reference/sweep-record-schema.md) — every
  `Canary::Eval::Record` field, including the non-score reasons.
- [Wire protocol](reference/wire-protocol.md) — the `POST /v1/rollouts`
  request/response shape.
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
