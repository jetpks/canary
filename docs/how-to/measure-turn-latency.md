# How-to: measure agentic turn latency and concurrent cache behavior

`bin/canary-loop-bench` drives `Canary::LoopBench` (`lib/canary/loop_bench.rb`):
`--concurrency N` independent `Canary::ToolLoop` conversations, run
concurrently as fibers in one Async reactor (never threads), each against
its own task (round-robin over one or more `--task` flags), each writing its
own JSONL transcript. One invocation is one **arm**: one `--model`, one
`--concurrency`. This closes BRIEF §7.6 — it measures, `bin/canary-tool-loop`
only proves the wire shape (see
[`run-the-tool-loop.md`](run-the-tool-loop.md#what-this-is-not)).

## Why this exists

Every agentic loop this project has run so far used the
`qwen3.8-27b-mxfp8-concurrent1` operating point purely by inheritance — it's
the point loaded for seeded scoring, which needs the drafter (BRIEF §3.5).
Nobody had measured whether the drafter's speculative-decode speedup still
wins at agentic **turn latency**, or what happens to the studio gateway's
16-entry RAM-only prefix cache (APC) when several tool-loop conversations
interleave against it. This bench is the machinery for both questions — it
makes no recommendation and draws no conclusion; the operating-point choice
from the numbers it produces is the architect's and the human's.

## One client per engine — never two invocations in flight

The studio box (`studio.slush.systems`) serves **one client at a time**. A
bench invocation's own `--concurrency N` fibers *are* the measured
concurrent load against one engine — that's the point — but two separate
`canary-loop-bench` invocations must never run against the studio gateway
at once. The gateway is hand-started with no `KeepAlive`: if it stops
answering mid-run, that's a real failure to record, not something to retry
around.

## The behavioral cache instrument

The gateway's `/metrics` exposes no cache/prefix/APC-named series, and the
OpenAI-compatible `usage` object on both edges carries only
`prompt_tokens`/`completion_tokens`/`total_tokens` — no cached-token detail.
There is no counter to read prefix-cache behavior off directly. Instead,
`summary.json`'s per-turn `elapsed_s` against `prompt_tokens` is read
**behaviorally**: within one conversation, whose prompt only grows, a
prefill that hits a still-resident cached prefix is fast; a jump in
`elapsed_s` at a stable-or-growing `prompt_tokens` with no corresponding
`completion_tokens` jump is the signature of an evicted prefix having to be
reprocessed. `--metrics-url` still snapshots `/metrics` verbatim
before/after every arm into `metrics-before.txt`/`metrics-after.txt`, for
whatever the request-duration and time-to-first-token histograms there may
independently show — neither is authoritative on its own.

## Run an arm

```console
CANARY_SERVER_TOKEN=docs-demo-token CANARY_SERVER_PORT=9294 \
  bundle exec ruby bin/canary-server
```

```console
CANARY_SERVER_TOKEN=docs-demo-token CANARY_TOOL_LOOP_API_KEY=sk-... \
  bundle exec ruby bin/canary-loop-bench \
  --model qwen3.8-27b-mxfp8-concurrent4 \
  --concurrency 4 \
  --task struct_vector --task comparable_money \
  --base-url https://studio.slush.systems/v1 \
  --canary-url http://127.0.0.1:9294 \
  --max-turns 5 \
  --tool-choice auto \
  --max-tokens 4096 \
  --metrics-url https://studio.slush.systems/metrics \
  --out artifacts/concurrent4-c4
```

Flags:

| flag | default | notes |
|---|---|---|
| `--model ALIAS` | *(required)* | the model id/alias every loop in this arm requests. |
| `--concurrency N` | `1` | number of concurrent `Canary::ToolLoop` conversations (fibers, one Async reactor). |
| `--task NAME` | `struct_vector` | repeatable; loops are assigned tasks round-robin over the list given. |
| `--base-url URL` | *(required)* | the model edge — an OpenAI-compatible `/v1`. |
| `--canary-url URL` | *(required)* | the tool edge — a running `bin/canary-server`. |
| `--max-turns N` | `Canary::ToolLoop::DEFAULT_MAX_TURNS` (6) | turn cap, per loop. |
| `--tool-choice auto\|required` | `auto` | first-turn-only, same semantics as `bin/canary-tool-loop`. |
| `--max-tokens N` | `4096` | per-request `max_tokens`, every turn, every loop. |
| `--out DIR` | *(required)* | one transcript JSONL per loop, `summary.json`, and (with `--metrics-url`) the before/after metrics snapshots. |
| `--metrics-url URL` | *(none)* | when given, `/metrics` is fetched verbatim before and after the arm. |

`CANARY_SERVER_TOKEN` (tool edge, required) and `CANARY_TOOL_LOOP_API_KEY`
(model edge, defaults to a placeholder — fine against the studio gateway,
which ignores auth) are read the same way `bin/canary-tool-loop` reads them.
The model-edge read timeout is a generous 900s: a drafter-less 4096-token
turn plus a cold engine swap (the first request naming a newly-loaded alias
triggers it, serialized gateway-side) can run many minutes.

## Reading `summary.json`

```json
{
  "loops": [
    {
      "loop_id": "loop-0",
      "task": "struct_vector",
      "outcome": "final_answer",
      "started_at": 1234.567,
      "finished_at": 1298.123,
      "transcript": "loop-0.jsonl",
      "turns": [
        {"finish_reason": "tool_calls", "prompt_tokens": 512, "completion_tokens": 40, "elapsed_s": 3.71},
        {"finish_reason": "stop", "prompt_tokens": 610, "completion_tokens": 88, "elapsed_s": 5.02}
      ]
    }
  ]
}
```

`outcome` is one of `final_answer`, `max_turns`, `truncated`, or
`loop_error` — the same typed outcome `Canary::ToolLoop#call` already
returns, carried straight through. `started_at`/`finished_at` are one
process's monotonic clock, comparable within the file (not wall time, not
comparable across a different run's `summary.json`) — two loops' intervals
overlapping is the concurrency proof. Every element of `turns` is built by
re-reading that loop's own transcript's `model_turn` entries — not by
teaching `Canary::ToolLoop` a new reporting seam — so the transcript stays
the single source of truth and `summary.json` is a derived index into it.

## `--max-tokens 4096` and `length` turns are first-class data

Every arm runs `--max-tokens 4096`. A turn whose `finish_reason` comes back
`"length"` (the model ran out of budget mid-turn) is never excluded or
retried — BRIEF §3.5's runaway-tail concern is part of the latency
distribution this bench exists to measure, so a `truncated` loop outcome
is as real a row in `summary.json` as a `final_answer` one.

## Unseeded by design — no scoring claim

Every arm this bench runs sends no seed and makes **no pass@k or
correctness claim anywhere** (Amendment 2). `§3.5`'s seeding discipline
binds *scoring* measurements; this bench measures latency and cache
behavior only. `run_tests` calls still execute for real against
`bin/canary-server` (a model genuinely submitting code as part of its own
tool use), but nothing here reads, aggregates, or reports whether they
passed — that signal stays inside the transcript's own `tool_result.response`,
unread by `summary.json`.

## Prove the shape offline

`test/canary/tool_loop/scripted_gateway.rb` now infers each conversation's
position in its script from the request itself (counting `"tool"`-role
messages already in `messages`) rather than shared mutable state, so one
gateway instance safely serves several interleaved `Canary::LoopBench`
loops at once:

```console
bundle exec ruby -Ilib test/canary/tool_loop/scripted_gateway.rb --port 9402 --script eval-then-tests-then-final
```

```console
CANARY_SERVER_TOKEN=docs-demo-token \
  bundle exec ruby bin/canary-loop-bench \
  --model scripted --concurrency 3 --task struct_vector \
  --base-url http://127.0.0.1:9402/v1 --canary-url http://127.0.0.1:9294 \
  --max-turns 6 --out /tmp/loop-bench-demo
```

`test/canary/loop_bench_test.rb` exercises the same thing in-process,
against real bound sockets for both edges (no mocking either collaborator) —
including a genuine transport failure (a closed port) to prove a turn whose
model response never arrived at all still gets a typed, non-nil
`finish_reason`/`prompt_tokens`/`completion_tokens` row rather than a nil.

## What this is not

- **Not a scoring run.** No seed, no pass@k, no correctness claim — see
  above.
- **Not a recommendation.** This bench reports raw per-turn numbers; it
  does not choose an operating point.
- **Not a direct cache counter.** Prefix-cache behavior is read off
  per-turn timing, never a dedicated metric — see "The behavioral cache
  instrument" above.
