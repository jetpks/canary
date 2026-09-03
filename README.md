# 🐤 canary

A Ruby coding evaluation harness, and the raw results of running it against
about thirty locally-served open-weight models and ten hosted ones.

- **What:** 44 hand-authored Ruby tasks, graded by executing each task's
  own test suite against the model's code in a forked child.
- **Results:** the [Canary Register](https://claude.ai/code/artifact/3a79cd91-5e26-4668-89e1-512d41b70437),
  built from the raw records under [`results/`](results/README.md).
- **Ruby:** 4.0.6, pinned in `mise.toml`.
- **License:** MIT.
- **Docs:** [`docs/`](docs/README.md), organised as tutorial, how-to,
  reference, explanation.

## What it measures

A task is a natural-language statement, a reference solution, a grading
test file (Minitest or RSpec), and a set of deliberately broken solutions
that each embody one named misconception. A model sees only the statement.
Its answer is extracted, parsed, written to a scratch file, and run
through the grader in a forked child process. It passes when the grader
passes. Nothing is scored by pattern-matching the code or by asking
another model.

The working thesis is that **Ruby is a tail-generalization canary**: there
is far less Ruby than Python in any training corpus, and Ruby lets
semantically wrong code parse and run cleanly, so a model that is guessing
rather than generalizing fails here silently and gets caught by the
grader. That is a thesis the project probes, not a finding it claims. See
[`docs/explanation/thesis.md`](docs/explanation/thesis.md).

## The results

Every sweep ever run is committed under `results/run-<timestamp>/`: one
`Canary::Eval::Record` per sample, the exact request and response behind
it, and the run's own configuration. The
[Canary Register](https://claude.ai/code/artifact/3a79cd91-5e26-4668-89e1-512d41b70437)
is a table built from the poolable subset of those runs: 29 local-model
arms on one Mac Studio (M4 Max, 128 GB), each 44 tasks × 3 samples at
temperature 1.0 under a stated output contract, reported as pass rate on
all 132 samples with a 95% interval bootstrapped by task, plus decode
throughput and resident memory measured beside the run.

How each number is computed, what pools with what, and what the corpus
cannot see is in
[`docs/explanation/methodology.md`](docs/explanation/methodology.md). What
the register does **not** claim: that canary is a benchmark, or that any
number is citable outside that machine. Intervals at n=132 are roughly
±10 points wide. The corpus resolves bands, not neighbours.

## Quickstart

```console
bundle install
bundle exec rake test
```

The suite runs offline, opens no socket, and reads no credential. Without
mise activated in your shell, prefix commands with `mise exec --` so the
pinned Ruby is the one that runs.

Grade one submission in-process, no model involved:

```console
bundle exec ruby -Ilib -e '
require "canary"
entry = Canary::TaskRepo.all.find { |e| e.name == "struct_vector" }
result = Canary::Verifier.new.call(entry.reference)
puts "#{result.passed} #{result.rollout_result.passed}/#{result.rollout_result.total}"
'
```

From there: [the tutorial](docs/tutorial.md) walks that call apart,
[run a sweep](docs/how-to/run-a-sweep.md) buys real samples from a real
model, and [author a task](docs/how-to/author-a-task.md) is the per-file
contract for adding to the corpus.

## How a sample is graded

The pipeline for one (task, model, sample) job, in
`Canary::Eval::Runner`:

1. **Render** (`Canary::Prompt`). The model gets a fixed system prompt
   stating the output contract (one fenced Ruby block, no prose, no
   tools) and the task statement. Nothing else from the task reaches it:
   not the category, not the grader, not the misconception catalogue.
   That is structural, and a test proves it by reflection.
2. **Sample** (`Canary::Sampler`, `Canary::Providers::*`). Temperature and
   a prompt-derived seed are stated on every request, so a re-run
   reproduces and the three samples of one task are independent draws.
   The exact request body and the raw response are written to
   `completions.jsonl` before the record is.
3. **Extract** (`Canary::Extractor`). The first Ruby-tagged or untagged
   fence is the submission. An unfenced answer is also a submission, so a
   model that wrote correct Ruby but skipped the fence is graded rather
   than dropped. Only an empty answer, or a fence tagged for another
   language, is a refusal.
4. **Prefilter** (`Canary::Prefilter`). A Prism parse, no execution. A
   parse error is a scored failure. A parse error anchored at end of
   input, on a response the provider cut off at its token limit, is a
   non-score instead: the harness never saw the whole answer.
5. **Rollout** (`Canary::Pool`, `Canary::Verifier`). A forked child loads
   the submission and the grader and reports pass/fail counts back over a
   pipe. The parent never runs the submission.
6. **Record** (`Canary::Eval::Record`). One JSON line. `scored: false`
   with a `non_score_reason` when the harness never got to judge the
   sample, so a harness limitation is never reported as a model failure.

`Canary::Server` exposes steps 4 and 5 as `POST /v1/rollouts` for callers
without a Ruby process, and `POST /v1/eval` runs one Ruby snippet in the
same forked child with no prefilter ahead of it.

## Where this is going

Everything above is one prompt, one answer, and every number in the
register comes from that instrument. The next question is how the same
models behave when they can run code and see test output before they
commit to an answer. Two early surfaces exist for that, unmeasured so far:

- **`Canary::ToolLoop`** (`bin/canary-tool-loop`) gives a chat model
  `ruby_eval` and `run_tests` as OpenAI tools, executes each call against a
  running `bin/canary-server`, and loops until the model answers or a turn
  cap is hit. [How-to](docs/how-to/run-the-tool-loop.md).
- **`Canary::LoopBench`** (`bin/canary-loop-bench`) runs several of those
  conversations concurrently against one model and summarises per-turn
  latency. [How-to](docs/how-to/measure-turn-latency.md).

Neither has produced a committed result yet, and neither feeds the
register. When they do, agentic runs will be reported as their own
measurement, not pooled with the one-shot rows.

## The corpus

44 tasks under `tasks/`: 38 authored from scratch, 6 adapted from dated
`rails/rails` pull requests and attested as such; 28 graded by Minitest,
16 by RSpec; 132 broken solutions in total. Each directory:

```text
tasks/struct_vector/
  meta.yml       # category, adapter, provenance, statement, one entry per broken solution
  solution.rb    # the reference solution
  grader.rb      # grades solution.rb and every broken/*.rb
  broken/
    mutates_operands.rb
    transposed_addition.rb
    mechanism_free.rb   # mandatory: the simplest mechanism-ignorant answer, which must fail
```

The suite enforces that every reference passes, every broken solution
fails, and broken solutions fail on distinct grader examples.
[`docs/CONTAMINATION.md`](docs/CONTAMINATION.md) states exactly what can
and cannot be claimed about whether a model has seen this material.

## What this is not

- **Not a benchmark.** Hand-built, 44 tasks, one machine. The register
  ranks bands, and says so.
- **Not a hardened sandbox.** Rollouts fork; they do not contain.
  `test/canary/tamper_test.rb` catalogues 19 grader-tampering vectors, and
  10 still succeed. [`docs/explanation/threat-boundary.md`](docs/explanation/threat-boundary.md)
  is the full accounting.
- **Not one pooled dataset.** Three record schemas exist on disk and they
  measure different things. The register uses schema 3 only.
  [`docs/reference/results-layout.md`](docs/reference/results-layout.md)
  says which runs are which.
