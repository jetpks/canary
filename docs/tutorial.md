# Tutorial: install, run the suite, grade one rollout

Every command below except the finale in step 4 was run against this
checkout to produce the output shown. None of it touches a network or
spends anything. The finale is presented, not executed, because it does
both.

## 1. Install

Ruby 4.0.6 is pinned in `mise.toml`. If mise is not activated in your
shell, prefix every command with `mise exec --`; a bare `bundle exec` under
some other Ruby fails with `Bundler::GemNotFound` against gems installed
for the pinned one.

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
Finished in 26.648339s, 12.7963 runs/s, 110.3258 assertions/s.

341 runs, 2940 assertions, 0 failures, 0 errors, 13 skips
```

The counts grow as the corpus and suite grow; the number that matters is
`0 failures, 0 errors`. The skips are the ten grader-tampering vectors the
sandbox does not yet close (see
[threat-boundary](explanation/threat-boundary.md)) and the live-provider
tests, which need `CANARY_LIVE=1` and a key.

One file instead of the whole suite:

```console
bundle exec ruby -Ilib -Itest test/canary/pool_failure_test.rb
```

## 3. Grade one rollout, in-process

The suite proves the harness works. This shows *how*, one call at a time:
load the corpus, pick a task, run its reference solution through
`Canary::Verifier`, and look at the result. No model, no network, no
process other than the child `Canary::Pool` forks itself.

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

```text
passed: true
prefilter clean: true
rollout outcome: ok
examples: 4/4 passed
```

What happened, in order (`lib/canary/verifier.rb`):

1. `Canary::TaskRepo.all` loaded every `tasks/**` directory into an
   `Entry`; `entry.reference` is a `Canary::Task` pointing at
   `struct_vector`'s `solution.rb` and `grader.rb`.
2. `Canary::Verifier#call` ran `Canary::Prefilter` over `solution.rb`
   first: a Prism parse, no execution. It came back clean, so the
   verifier went on to a rollout.
3. `Canary::Pool#rollout_task` forked a child, loaded `solution.rb` and
   `grader.rb` into it, ran the grader's Minitest suite, and reported the
   result back over a pipe: 4 examples, 4 passed, outcome `:ok`.

Swap `entry.reference` for `entry.broken_solutions.first` to watch the same
path report a failure. [Author a task](how-to/author-a-task.md) explains
what a broken solution is for.

## 4. The finale: sweep the corpus against a real model

Everything above ran offline against a reference solution.
`bin/eval_sweep.rb` runs the same pipeline at corpus scale against a real
model: every task, three samples each, one command. It takes one
positional argument, the model id.

**Presented, not executed.** This spends money, or ties up a local
inference box, and is not run as part of producing this page.

```console
CANARY_LIVE=1 bundle exec ruby bin/eval_sweep.rb qwen/qwen3-coder-plus
```

- `CANARY_LIVE=1` is the only spend gate. Without it the script aborts
  before reading a key or opening a socket.
- A single model id narrows the run to that model, so only its provider's
  key is demanded. This one routes through OpenRouter and needs
  `OPENROUTER_API_KEY`, nothing else.
- An id that is not a key of `EvalSweep::MODEL_PROVIDERS` aborts before any
  of that, naming the ids it knows.
- A local model behind an OpenAI-compatible gateway is the same command
  with its alias, and needs no key at all:

  ```console
  CANARY_LIVE=1 CANARY_STUDIO_CONCURRENCY=1 bundle exec ruby bin/eval_sweep.rb qwen3.8-27b-mxfp4
  ```

- Before any call, the script derives and prints a spend cap from the
  model that will run, and stops the run if recorded spend exceeds it.
- Artifacts land in a fresh `results/run-<timestamp>/`: `run_config.json`
  (what the run was drawn under), `sweep.jsonl` (one record per sample),
  `completions.jsonl` (the request and response behind each), and
  `summary.md`. See
  [`results/run-20260902T042346Z/summary.md`](../results/run-20260902T042346Z/summary.md)
  for a finished local run.

From here: [run a sweep](how-to/run-a-sweep.md) for every knob,
[results layout](reference/results-layout.md) for what a run directory
means, and [methodology](explanation/methodology.md) for how the register
reads them.
