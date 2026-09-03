# Explanation: methodology

How the numbers in the Canary Register are derived from `results/`, what
pools with what, and what the instrument cannot see. Everything about pass
rates and intervals below is reproducible from this repository alone.
Throughput and memory were measured beside the runs on the serving
machine, and this page says exactly where those numbers came from so they
can be weighed accordingly.

## The instrument

44 hand-authored Ruby tasks, hidden grader, three samples per task at
temperature 1.0 with a prompt-derived seed per sample, under a stated
output contract (schema 3: a system prompt asking for one fenced Ruby
block, no prose, no tools). A sample passes when the task's own test
suite passes against the model's code in a forked child. `max_tokens` is
4096 on the later runs and 16 384 on the earlier ones, recorded per run in
`run_config.json`.

Ruby is the language because it is a tail-generalization canary, stated
as a thesis and not a finding: [thesis.md](thesis.md).

## The machine

One Mac Studio, M4 Max, 128 GB unified memory, running mlx-vlm behind a
local OpenAI-compatible gateway, one model resident at a time, one
request in flight. Every local number in the register was produced there.
The engine version matters for throughput: a speculative-decoding
regression between mlx-vlm releases changed one model's decode rate by
half with the same weights, so every throughput figure names the engine
version it was measured on.

## Pass rate

The register reports **pass rate on all 132 samples**, with truncations,
refusals and transport errors counted as failures. Call this the *serving
reading*: if you deploy the model and send it the task, this is how often
you get a passing answer back.

`summary.md` inside each run reports a different number, `pass_at_1` from
`Canary::Eval::Report`, which keeps non-scores **out** of the denominator.
Call this the *capability reading*: of the answers the harness could
judge, how many passed. Both are right; they answer different questions.
The register uses the serving reading because a model that runs out its
token budget guessing at hidden tests has not solved the task, and hiding
that would flatter exactly the models that fail slowly. The two readings
diverge most on the arms with many unscored samples; the register's
`unscored` and `truncated` columns show how far.

Where a run has a `rescore-*.jsonl` sidecar, the newest one is used
instead of `sweep.jsonl`. See [rescore a run](../how-to/rescore-a-run.md).

## Intervals

A task's three samples are not independent: they share a prompt, and a
task is either in a model's reach or not. So the 95% interval is a
**bootstrap clustered by task**: resample the 44 tasks with replacement,
pool the passes and samples of the tasks drawn, take the percentile
interval of the pooled rate over 10 000 resamples. Seed 20260901. This is
wider than a per-sample binomial interval, and correctly so. Typical
half-width at n=132 is 9 to 12 points, which is the number to keep in mind
when reading the table: the corpus resolves bands, not neighbours.

```ruby
require "json"

recs = File.readlines(ARGV[0]).map { |l| JSON.parse(l) }.select { |r| r["render_mode"] == "hidden" }
by_task = recs.group_by { |r| r["task_name"] }.values.map { |rs| [rs.count { |r| r["passed"] }, rs.size] }
rng = Random.new(20_260_901)
rates = Array.new(10_000) do
  p = t = 0
  by_task.size.times { pr, tt = by_task[rng.rand(by_task.size)]; p += pr; t += tt }
  100.0 * p / t
end.sort
puts format("%.1f%% [%.1f, %.1f]", 100.0 * by_task.sum(&:first) / by_task.sum(&:last), rates[250], rates[9_749])
```

Run against a run's `sweep.jsonl` (or its newest `rescore-*.jsonl`) it
reproduces the register's pass rate and interval for that row.

Head-to-heads between two arms on the same corpus are **paired by task**:
the difference in passes per task, tested with a sign-flip permutation
test. A paired test can call a difference the two overlapping intervals
cannot, and the register quotes the paired p-value wherever it makes a
comparative claim.

## What pools with what

Only schema-3 runs with all 132 hidden samples enter the table.
[results-layout.md](../reference/results-layout.md) §Three schemas gives
the reasons in full; the short version is that schema 1 had no stated
sampling and no output contract, schema 2 fixed sampling but not the
contract, and the contract is an input change. The hosted frontier models
were run under schema 1 on a 34-task corpus, and are quoted only as a
ceiling, never in the same table.

Within schema 3, runs at `max_tokens` 4096 and 16 384 are pooled with the
cap stated per row. 4096 sits above the p99 of schema-3 passing answers,
so it bites only answers that were already pathological; the register's
`truncated` column shows where it bit.

## Throughput

Decode tokens per second comes from the engine's own per-request log line,
not from canary. It is the **median over every request in the run's
window that generated at least 50 tokens, grouped by the checkpoint the
engine logged**. Grouping by logged checkpoint matters: a gateway that
falls back to another resident model on a stale registry entry would
otherwise contaminate the tail, and an earlier draft of the table got one
row wrong exactly that way by sampling the last five requests.

Wall clock per sample is canary's own `sample_ms`, which includes prefill
and queueing. Both are reported because they answer different questions:
decode rate is what a token stream feels like, wall clock is what a
sweep costs.

The engine logs are not in this repository. The throughput columns are
therefore reproducible from the serving machine only, and the register
labels them as such.

## Memory

Resident memory is `phys_footprint` and `phys_footprint_peak` from
`footprint -p` on the engine child, sampled every ten seconds across the
run. Where only `ps rss` was captured the table says so; it under-read a
16k-token reasoning run by 20 GB because the KV cache lives in wired
memory that RSS does not count. Memory values were transcribed by hand
from the lab notes with the instrument recorded per value.

## What canary cannot see

One-shot, no tools, no multi-turn, prompts of roughly 230 tokens. Tool
calling fidelity, long-context behaviour, agentic recovery, and anything
about a model's behaviour past its first answer are out of frame. Every
"best model" statement in the register inherits that frame. A model that
scores well here is a model that writes correct Ruby from a short
specification on the first try, and nothing more is claimed.

## What is not claimed

That canary is a benchmark. That any number is citable outside the
machine it was measured on. That an ordering inside a band is real when
the intervals overlap. That the corpus is unseen by any model:
[CONTAMINATION.md](../CONTAMINATION.md) says exactly what is and is not
known about that.
