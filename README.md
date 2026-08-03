# canary

A Ruby coding evaluation and RL environment.

## What this is

canary is a harness for running model-generated Ruby solutions against small,
hand-authored coding tasks and scoring them by actually executing their test
suite — not by pattern-matching the code. Each task pairs a natural-language
statement with a reference solution, a grading test file (minitest or rspec),
and a set of deliberately broken solutions that each embody one named
misconception. A `Canary::Pool` forks a fresh child process per rollout,
loads the untrusted submission into it, runs it through the task's grader,
and reports back a structured `Canary::RolloutResult` — pass/fail counts,
coverage, and an outcome (`:crash`, `:timeout`, `:invalid`, etc.) — without
ever letting the submission run in the parent process.

## The thesis

The project's working thesis is that **Ruby is a tail-generalization
canary**: its combination of corpus scarcity (far less public training data
than Python or JavaScript) and syntactic permissiveness (weak or incorrect
code often still parses and runs, just wrong) means a model that is actually
generalizing should still produce working Ruby, while a model that is mostly
pattern-matching against memorized solutions is more likely to fail — and to
fail *silently*, producing code that runs without erroring but gets the
semantics wrong. This is a thesis the project is built to probe, not a
finding it has established.

## What exists today

- **The task corpus** (`tasks/`) — a small set of hand-authored Ruby tasks,
  each with a reference solution and a handful of broken solutions modeling
  specific misconceptions (see "Task layout" below).
- **The fork-pool verifier** (`Canary::Pool`, `lib/canary/pool.rb`) — runs a
  submission or a full task (solution + grader) in a forked child, collects
  the result over a pipe, and enforces a timeout and a per-process-group
  kill so a hung or runaway submission can't block the harness.
- **The static prefilter** (`Canary::Prefilter`, `lib/canary/prefilter.rb`)
  — inspects a submission without executing it: a Prism parse (tier 0) and,
  if that succeeds, RuboCop's Lint department run in-process (tier 1). It
  exists to reject what can be rejected for free, before a rollout is paid
  for; it never scores or grades on its own.
- **The prompt renderer** (`Canary::Prompt`, `lib/canary/prompt.rb`) — turns
  a task's statement into model-facing prompt text. Hidden mode (the
  default) shows only the statement; grader-visible mode also shows the
  grading test file and is meant for diagnostic use, not normal sampling.
- **The sampler** (`Canary::Sampler`, `lib/canary/sampler.rb`) — drives a
  provider (currently `Canary::Providers::Anthropic`, wrapping the
  `anthropic` gem's client) for `n` completions per task, recording every
  dispatched request/response as a JSON line before returning. Two
  independent guards bound a run: a request-count budget checked before
  dispatch, and an optional dollar cap accumulated from each response's
  reported usage against a caller-supplied price table. A response the
  provider cut short at its token limit is a failure rather than a
  short answer, so a truncated completion is never scored as if the model
  had finished — the response is still recorded, since its text is the only
  copy there is.
- **The extractor** (`Canary::Extractor`, `lib/canary/extractor.rb`) —
  models answer in fenced markdown, not in source files. This pulls the
  Ruby out of that answer, and reports a distinct outcome when there is
  nothing it can honestly extract, so "the model declined" stays
  distinguishable from "the model wrote broken code."
- **`Canary::Verifier`** (`lib/canary/verifier.rb`) composes the prefilter
  and the pool into one call per task: a submission that the prefilter
  rejects never reaches a rollout.

## Running the test suite

    bundle install
    bundle exec rake test

This runs every `test/**/*_test.rb` file under Minitest (see `Rakefile`). To
run a single file:

    bundle exec ruby -Ilib -Itest test/canary/pool_failure_test.rb

## Task layout

Each task is a directory under `tasks/` (13 as of this writing — see
"What this is not yet" below), loaded by `Canary::TaskRepo`
(`lib/canary/task_repo.rb`). For example, `tasks/struct_vector/`:

    tasks/struct_vector/
      meta.yml       # category, adapter, statement, and one entry per broken solution
      solution.rb    # the reference solution
      grader.rb      # the test file that grades both solution.rb and each broken/*.rb
      broken/
        mutates_operands.rb
        transposed_addition.rb
        mechanism_free.rb

`meta.yml` names the adapter (`minitest` or `rspec`), the task's category,
its natural-language statement, and — for each file under `broken/` — an id
and a free-text `misconception` describing the specific mistake that
solution embodies. `TaskRepo.all` loads every task directory into a
`Canary::TaskRepo::Entry`, pairing the reference solution and each broken
solution with the shared grader as `Canary::Task` values that
`Canary::Pool#rollout_task` runs directly.

## What this is not yet

- **The corpus is small.** `Canary::TaskRepo.all.size` returns 13. It is a
  hand-authored probe, not a benchmark, and it is not claimed to be
  comprehensive.
- **The sandbox is not hardened.** Rollouts run in a forked child, not a
  sandboxed or contained one. `test/canary/tamper_test.rb` is an executable
  catalogue of grader-tampering attacks against the current pool: as of this
  writing, 10 of its 19 named vectors still succeed against the harness
  (each recorded as a `skip` naming the vector and what it forges), and 9
  are defended by a real assertion. This work is open and ongoing — nothing
  in this repo should be read as a claim that submissions are safely
  contained.
- **No model has been evaluated against this corpus.** There is no scoring
  run, no leaderboard, and no result to cite.
- **No performance or throughput claims are made here.** None are published
  in this README.
