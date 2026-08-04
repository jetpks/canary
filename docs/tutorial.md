# Tutorial: install, run the suite, sweep a model

Every command below, except the finale in step 4, was run against a clean
checkout to produce the output shown. None of it touches a network or spends
anything — the finale is presented, not executed, because it does both.

## 1. Install

```console
bundle install
```

```text
Bundle complete! 2 Gemfile dependencies, 50 gems now installed.
Use `bundle info [gemname]` to see where a bundled gem is installed.
```

## 2. Run the test suite

```console
bundle exec rake test
```

```text
Finished in 23.955461s, 9.6429 runs/s, 61.1134 assertions/s.

231 runs, 1464 assertions, 0 failures, 0 errors, 13 skips
```

The run/assertion/skip counts grow as the corpus and suite grow; the number
that matters is `0 failures, 0 errors`.

To run one file instead of the whole suite:

```console
bundle exec ruby -Ilib -Itest test/canary/pool_failure_test.rb
```

## 3. Run one offline, in-process rollout

The suite above proves the harness works. This step shows *how* it works,
one call at a time: load the corpus, pick a task, run its reference solution
through `Canary::Verifier`, and look at the real result — no model, no
network, no forked-off test runner other than the one `Canary::Pool` starts
itself.

```console
bundle exec ruby -Ilib -e '
require "canary"

entry = Canary::TaskRepo.all.find { |e| e.name == "struct_vector" }
result = Canary::Verifier.new.call(entry.reference)

puts "passed: #{result.passed}"
puts "prefilter clean: #{result.prefilter_report.clean?}"
puts "rollout outcome: #{result.rollout_result.outcome}"
puts "examples: #{result.rollout_result.passed}/#{result.rollout_result.total} passed"
'
```

Observed output:

```text
passed: true
prefilter clean: true
rollout outcome: ok
examples: 4/4 passed
```

What happened, in order (see `lib/canary/verifier.rb`):

1. `Canary::TaskRepo.all` loaded every `tasks/**` directory into an `Entry`;
   `entry.reference` is a `Canary::Task` pointing at `struct_vector`'s
   `solution.rb` and `grader.rb`.
2. `Canary::Verifier#call` ran `Canary::Prefilter` against `solution.rb`
   first — a static Prism parse, no execution. It came back clean, so the
   verifier went on to a real rollout.
3. `Canary::Pool#rollout_task` forked a child process, loaded `solution.rb`
   and `grader.rb` into it, ran the grader's Minitest suite against the
   solution, and reported the result back over a pipe — 4 examples, 4
   passed, outcome `:ok`.

Swap `"struct_vector"` for `entry.broken_solutions.first.task` to watch the
same path report a failure instead of a pass — see
[`how-to/author-a-task.md`](how-to/author-a-task.md) for what a broken
solution actually looks like.

## 4. The finale: sweep the whole corpus against one real model

Everything above ran in-process, offline, against a reference solution.
`bin/eval_sweep.rb` runs the same shape at corpus scale, against a real
model, through a real provider — every task in `Canary::TaskRepo.all`,
hidden arm plus grader-visible arm, in one command. It takes a single
positional argument: the model id to run.

**Presented, not executed** — like
[`how-to/run-a-sweep.md`](how-to/run-a-sweep.md)'s live invocation, this is
shown for reference only; it is not run as part of producing this doc,
because it spends real money against a real provider API:

```console
CANARY_LIVE=1 bundle exec ruby bin/eval_sweep.rb qwen/qwen3-coder-plus
```

- `CANARY_LIVE=1` is the only spend gate (`EvalSweep.load_env!`) — nothing
  above it reads an env file, demands a key, or opens a socket.
- Narrowing to one model narrows the key demand too: only that model's
  provider key is required. `qwen/qwen3-coder-plus` routes through
  OpenRouter (`EvalSweep::MODEL_PROVIDERS`), so this run needs
  `OPENROUTER_API_KEY` — set as an environment variable, never a credential
  file — and nothing else; `ANTHROPIC_API_KEY` and `FIREWORKS_API_KEY` are
  not demanded.
- A model id that isn't a key of `EvalSweep::MODEL_PROVIDERS` aborts before
  any of the above happens, naming the models it does know.
- Every OpenRouter model is hidden-only: the grader-visible arm only ever
  runs the two Anthropic anchors (`EvalSweep::VISIBLE_MODELS`), so this run
  produces hidden-arm records only — the visible arm is skipped entirely,
  not run and hidden.
- Before making any call, the script derives and prints a spend cap from
  exactly the model that will run (`EvalSweep.spend_cap_derivation` — 3x the
  worst case if every call maxed out its token budget) and wires it into a
  `Canary::Sampler::SpendGuard` that stops the run if real, recorded spend
  exceeds it.
- Artifacts land in a fresh `results/run-<timestamp>/` directory: `sweep.jsonl`
  (one `Canary::Eval::Record` per line), `completions.jsonl` (the raw
  request/response pairs behind those records), and `summary.md` (actual
  spend, the cap derivation, and a per-model/per-task pass table). See
  [`results/run-20260804T035621Z/summary.md`](../results/run-20260804T035621Z/summary.md)
  — a run already committed to this repo — for what a finished run's spend
  reporting actually looks like.

From here: [author a task](how-to/author-a-task.md),
[run a sweep](how-to/run-a-sweep.md) for the full-corpus / multi-model
invocation and `CANARY_SWEEP_SKIP`, or [run the wire
server](how-to/run-the-server.md).
