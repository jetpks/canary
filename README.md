# canary

A Ruby coding evaluation and RL environment. **Status: incubating** — the
corpus, the eval pipeline, and the wire protocol are all still in active
flux. Nothing here is a finished product, and no result in this repo is
published as a citable benchmark number.

## The hypothesis

canary's working thesis is that **Ruby is a tail-generalization canary**: a
model that is actually generalizing, rather than pattern-matching against
memorized solutions, should keep producing working Ruby even in places where
Python or JavaScript training data would let it coast on retrieval instead.
Two properties make Ruby suited to measuring that gap:

- **Corpus scarcity.** There is far less public Ruby than Python or
  JavaScript for a model to have memorized against, so solving a Ruby task
  is more likely to require genuine generalization than recall.
- **Syntactic permissiveness.** Ruby tolerates a wide range of code that is
  syntactically fine and semantically wrong: a subtly incorrect method still
  parses, still runs, and often still returns something plausible-looking.
  A model that is guessing rather than reasoning is more likely to fail
  *silently* here — producing code that looks right and executes cleanly
  but gets the semantics wrong — than in a language where the same mistake
  would refuse to parse. That silence is a feature of the instrument, not a
  defect in it: it's exactly the failure mode a shallow pattern-matcher
  should produce, and a harness that only checked for a crash would miss it
  entirely.

This is a thesis the project is built to probe, not a finding it has
established. Nothing in this repo — no committed sweep, no leaderboard —
claims to have confirmed it. See [`docs/explanation/thesis.md`](docs/explanation/thesis.md)
for the longer version.

## What this is

canary is a harness for running model-generated Ruby solutions against
small, hand-authored coding tasks and scoring them by actually executing
their test suite — not by pattern-matching the code. Each task pairs a
natural-language statement with a reference solution, a grading test file
(minitest or rspec), and a set of deliberately broken solutions that each
embody one named misconception.

- **The task corpus** (`tasks/`) — hand-authored Ruby tasks, each with a
  reference solution and broken solutions modeling specific misconceptions
  (see "Task layout" below).
- **`Canary::TaskRepo`** (`lib/canary/task_repo.rb`) — loads `tasks/**` into
  `Canary::TaskRepo::Entry` values, each pairing a reference solution and its
  broken solutions with a shared grader.
- **`Canary::Pool`** (`lib/canary/pool.rb`) — forks a fresh child process per
  rollout, loads the untrusted submission into it, runs it through the
  task's grader, and reports back a structured `Canary::RolloutResult`
  (pass/fail counts, coverage, and an outcome — `:ok`, `:error`, `:crash`,
  `:timeout`, `:invalid`) without ever letting the submission run in the
  parent process.
- **`Canary::Prefilter`** (`lib/canary/prefilter.rb`) — inspects a
  submission without executing it. A Prism parse (tier 0) is always on and
  gates only on parse errors, never parse warnings. An opt-in RuboCop
  Lint-department pass (tier 1, off by default — pass `lint: true` to enable
  it) gates only findings at RuboCop's `:error`/`:fatal` severity; a
  `:warning`-level finding stays visible in the report but never blocks a
  rollout. What decides whether a finding gates is its severity, never which
  tier or tool emitted it. It exists to reject what can be rejected for
  free, before a rollout is paid for; it never scores or grades on its own.
- **`Canary::Verifier`** (`lib/canary/verifier.rb`) — composes the prefilter
  and the pool into one call per task: a submission the prefilter rejects
  never reaches a rollout.
- **`Canary::Prompt`** (`lib/canary/prompt.rb`) — turns a task's statement
  into model-facing prompt text. Hidden mode (the default) shows only the
  statement; grader-visible mode also shows the grading test file and is
  meant for diagnostic use, not normal sampling.
- **`Canary::Sampler`** (`lib/canary/sampler.rb`) — drives a provider
  (`Canary::Providers::Anthropic` or `Canary::Providers::OpenAICompat`) for
  `n` completions per task, recording every dispatched request/response as a
  JSON line before returning. A request-count budget and an optional dollar
  spend guard bound a run.
- **`Canary::Extractor`** (`lib/canary/extractor.rb`) — pulls the Ruby out
  of a model's fenced-markdown answer, and reports a distinct outcome when
  there is nothing it can honestly extract, so "the model declined" stays
  distinguishable from "the model wrote broken code."
- **`Canary::Eval::Runner`** (`lib/canary/eval/runner.rb`) — the sweep
  orchestrator: render → sample → extract → verify, once per (task, model,
  sample) job, yielding one `Canary::Eval::Record` per job. A response the
  provider cut short at its token limit is not automatically thrown away: if
  the extracted code still parses cleanly, it is graded normally, with the
  provider's `stop_reason` preserved on the record for audit. Only a
  response that cuts off mid-construct — one the prefilter's own parser
  can't finish parsing — is excluded from scoring, and even that is recorded
  as an explicit non-score reason rather than silently dropped.
- **`Canary::Server`** (`lib/canary/server.rb`) — a single-shot wire surface,
  `POST /v1/rollouts` over HTTP/1.1, for scoring one submission per request
  without a Ruby process in the caller.

## Running the test suite

    bundle install
    bundle exec rake test

This runs every `test/**/*_test.rb` file under Minitest (see `Rakefile`). To
run a single file:

    bundle exec ruby -Ilib -Itest test/canary/pool_failure_test.rb

## Task layout

Each task is a directory under `tasks/` (`Canary::TaskRepo.all.size` is the
current count — see "What this is not yet" below), loaded by
`Canary::TaskRepo` (`lib/canary/task_repo.rb`). For example,
`tasks/struct_vector/`:

    tasks/struct_vector/
      meta.yml       # category, adapter, provenance, statement, one entry per broken solution
      solution.rb    # the reference solution
      grader.rb      # the test file that grades both solution.rb and each broken/*.rb
      broken/
        mutates_operands.rb
        transposed_addition.rb
        mechanism_free.rb

`meta.yml` names the adapter (`minitest` or `rspec`), the task's category,
its provenance (`authored` or `sourced`), its natural-language statement,
and — for each file under `broken/` — an id and a free-text `misconception`
describing the specific mistake that solution embodies. See
[`docs/how-to/author-a-task.md`](docs/how-to/author-a-task.md) for the full
per-file contract.

## What this is not yet

- **The corpus is small.** `Canary::TaskRepo.all.size` is the current count.
  It is a hand-authored probe, not a benchmark, and it is not claimed to be
  comprehensive.
- **The sandbox is not hardened.** Rollouts run in a forked child, not a
  sandboxed or contained one. `test/canary/tamper_test.rb` is an executable
  catalogue of grader-tampering attacks against the current pool, and a
  real subset of them still succeed — falling into four accepted, documented
  classes of the same underlying limit of process-fork isolation on a single
  machine. Nothing in this repo claims submissions are safely contained.
  Full accounting: [`docs/explanation/threat-boundary.md`](docs/explanation/threat-boundary.md).
- **No published result exists.** `results/` carries committed raw sweep
  artifacts — completions and `Canary::Eval::Record` data from real
  dispatches — not a scored leaderboard. No leaderboard or citable pass-rate
  claim is published anywhere in this repo; the artifacts are exactly that,
  artifacts, not a result.
- **No performance or throughput claims are made here.** None are published
  in this README.

## Documentation

Depth that doesn't belong on a front page lives under
[`docs/`](docs/README.md), organized as tutorial, how-to, reference, and
explanation. Start there for: running an offline rollout end-to-end,
authoring a new task, running a sweep, running the wire server, the
`meta.yml`/record/wire-protocol schemas, and the contamination posture
(`docs/CONTAMINATION.md`).
