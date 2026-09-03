# Reference: results layout

`results/` holds every sweep this project has run, raw. Nothing in it is a
leaderboard. The [Canary Register](../explanation/methodology.md) is built
from a subset of these directories, and this page says which subset and
why.

## One run

```text
results/run-20260902T042346Z/
  run_config.json      # what the run was drawn under (schema 3 and later)
  sweep.jsonl          # one Canary::Eval::Record per sample
  completions.jsonl    # per sample: the request body sent, the raw response received
  summary.md           # spend, config, per-arm pass tables
  rescore-<stamp>.jsonl   # optional: the record set re-graded by bin/rescore.rb
  rescore-<stamp>.json    # optional: the rescore manifest
```

The directory name is the UTC start time. A run is never overwritten; a
re-run is a new directory.

### `run_config.json`

Written first, before any call:

```json
{
  "schema_version": 3,
  "generated_at": "2026-09-02T04:23:46Z",
  "tasks": 44,
  "hidden_k": 3,
  "visible_k": 1,
  "max_tokens": 4096,
  "temperature": 1.0,
  "seed_derivation": "sha256(prompt + sample_index)[0,8]",
  "concurrency": { "qwen3.8-27b-mxfp4": 1 },
  "providers":   { "qwen3.8-27b-mxfp4": "studio" },
  "extra_body":  { "qwen3.8-27b-mxfp4": { "reasoning_effort": "none" } },
  "system_prompt": "You are completing a self-contained Ruby coding task.\n..."
}
```

Runs before schema 3 have no `run_config.json`; their concurrency and
sampling parameters are not recoverable from disk, which is why the file
exists.

### `sweep.jsonl`

One JSON object per line, one line per (task, model, sample index). Fields
in [sweep-record-schema.md](sweep-record-schema.md). The order is
completion order, not task order.

### `completions.jsonl`

One JSON object per dispatched call:

```json
{
  "model": "qwen3.8-27b-mxfp4",
  "mode": "hidden",
  "task_name": "struct_vector",
  "sample_index": 0,
  "request":  { "model": "...", "max_tokens": 4096, "temperature": 1.0, "seed": 1799810450, "messages": [...], "reasoning_effort": "none" },
  "response": { ...the provider's raw response, verbatim... }
}
```

`request` is the body that went on the wire, captured through the
provider's `on_request` hook, not a reconstruction. Before schema 3 this
held `{prompt:}` only. `response` is verbatim and includes whatever
reasoning the provider returned; see
[CONTAMINATION.md](../CONTAMINATION.md) §Reasoning traces before
republishing.

### `rescore-*.jsonl` and `rescore-*.json`

Added by [`bin/rescore.rb`](../how-to/rescore-a-run.md) when an extractor
change alters what a run's answers grade to. The `.jsonl` is the whole
record set with the affected rows re-graded and everything else verbatim;
the `.json` manifest lists the tasks touched and the tallies before and
after. The original `sweep.jsonl` is untouched. A reader should prefer the
newest sidecar when one exists, and the register does.

## Three schemas, three measurements

`schema_version` is a plain field on every record. It is not cosmetic: the
three versions on disk were drawn under different conditions and their
rates do not pool.

| schema | runs | what changed | pools with |
|---|---|---|---|
| 1 | `run-20260803T044357Z` through `run-20260827T223029Z` | the original pipeline. Every hosted run, the seven Arm H runs, the first local runs. Sampling was whatever the server defaulted to: hosted endpoints sampled at 1.0, the local engine decoded greedily, so a local `k=3` run is one draw recorded three times. The seed, where sent, correlated samples across tasks. No output contract was stated, so part of every hidden-arm score is whether the model guessed that an unfenced answer would be discarded. The corpus was 34 tasks for the hosted runs. | nothing later |
| 2 | `run-20260827T224653Z` through `run-20260828T003027Z` | temperature and a prompt-derived seed stated on every request; `sample_ms` recorded; sample-major scheduling. Still no output contract. Four full runs. | other v2 runs |
| 3 | `run-20260901T054934Z` onward | a system prompt states the output contract (one fenced Ruby block, no prose, no tools). `run_config.json` written. `completions.jsonl` carries the real request body. The v2→v3 change is an *input* change, so v2 and v3 rates measure different questions. | other v3 runs |

To list which is which from a checkout:

```console
ruby -rjson -e 'Dir.glob("results/run-*").sort.each { |d| r = JSON.parse(File.readlines("#{d}/sweep.jsonl").first) rescue next; puts "#{File.basename(d)} v#{r["schema_version"]} #{r["model"]}" }'
```

Within a schema, two more things must match for rates to pool: the task
count (44 since 2026-08-27; hosted runs saw 34) and `max_tokens`. Runs at
16 384 and at 4096 both exist under schema 3; `run_config.json` says
which, and the cap bites only answers past the schema-3 p99, so the
register pools them with that stated.

## What the register uses

Every schema-3 run with all 132 hidden-arm samples present. That is 29
runs across 26 local aliases as of 2026-09-03. Excluded on purpose:

- every schema-1 and schema-2 run, for the reasons above;
- `granite-4.1-8b`, which scored 0 of 132 with every answer a fenced
  block that failed its grader. That was judged a broken serving build
  rather than a model score, and the row was dropped rather than reported
  as 0%;
- grader-visible arms, which exist only on the two Anthropic anchors and
  are a diagnostic of grader strength, not a score.

The hosted schema-1 runs are quoted in the register only as a ceiling and
never in the same table.

## Legacy files

`results/sweep.jsonl` and `results/summary.md` at the top level are the
first-ever sweep (91 records over 13 tasks, two Anthropic models,
2026-08-02). They predate the run-directory layout and the spend line, and
are kept because a run you can't re-read is a run you have to re-buy.
