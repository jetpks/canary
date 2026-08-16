# How-to: run the tool loop

`bin/canary-tool-loop` drives `Canary::ToolLoop` (`lib/canary/tool_loop.rb`):
a chat model gets canary's two verbs — `ruby_eval` and `run_tests` — as
OpenAI tool definitions, issues `tool_calls` through an OpenAI-compatible
`/v1/chat/completions` edge, has each call executed against a real
`bin/canary-server` over loopback HTTP, and receives the wire's typed JSON
response back **verbatim** as the tool result. The loop continues until the
model answers with no further tool calls, a response comes back truncated
(`finish_reason: "length"`), or `--max-turns` is reached. This is plumbing
proof, not measurement — see "What this is not" below.

It boots neither edge itself: both a model-serving endpoint and
`bin/canary-server` are the caller's job, same as `bin/canary-server`
boots nothing on its own behalf either.

## Boot the tool edge

```console
CANARY_SERVER_TOKEN=docs-demo-token CANARY_SERVER_PORT=9294 \
  bundle exec ruby bin/canary-server
```

## Run the loop against it

Any OpenAI-compatible `/v1/chat/completions` endpoint works for
`--base-url` — an OpenRouter/Fireworks-style host, or (as here) a locally
served model behind a gateway. `CANARY_SERVER_TOKEN` (the same token the
server above was booted with) authenticates the tool edge;
`CANARY_TOOL_LOOP_API_KEY` authenticates the model edge and defaults to a
placeholder if unset — fine for an edge that ignores auth (the studio
gateway does, `bin/eval_sweep.rb`'s own precedent).

```console
CANARY_SERVER_TOKEN=docs-demo-token CANARY_TOOL_LOOP_API_KEY=sk-... \
  bundle exec ruby bin/canary-tool-loop \
  --task struct_vector \
  --base-url https://studio.slush.systems/v1 \
  --model qwen3.8-27b-mxfp8-concurrent1 \
  --canary-url http://127.0.0.1:9294 \
  --max-turns 6 \
  --tool-choice auto \
  --transcript /tmp/tool-loop.jsonl
```

Flags:

| flag | default | notes |
|---|---|---|
| `--task NAME` | `struct_vector` | must match a `Canary::TaskRepo` entry name. |
| `--base-url URL` | *(required)* | the model edge — an OpenAI-compatible `/v1`. |
| `--model ALIAS` | *(required)* | the model id/alias to request. |
| `--canary-url URL` | *(required)* | the tool edge — a running `bin/canary-server`. |
| `--max-turns N` | `Canary::ToolLoop::DEFAULT_MAX_TURNS` (6) | turn cap; exceeding it ends the loop as a typed `max_turns` outcome rather than hanging. |
| `--tool-choice auto\|required` | `auto` | applies to the **first turn only** — every later turn is `auto` regardless, since `required` on every turn could never terminate. |
| `--transcript PATH` | *(required)* | where the JSONL transcript is written (overwrites a stale file at that path first). |
| `--max-tokens N` | `Canary::Providers::OpenAICompat::DEFAULT_MAX_TOKENS` (4096) | per-request `max_tokens`, sent on every turn. |

The bin prints exactly one final stdout line:

```text
OUTCOME: final_answer
```

— one of `final_answer` (the model answered with no further tool calls),
`max_turns` (the cap was hit), `truncated` (a response came back
`finish_reason: "length"`), or `loop_error` (a wire-contract violation or a
tool-edge transport failure; the process also exits non-zero in this case).
Everything else the loop did lives in the transcript, not on stdout.

## Reading the transcript

One JSON object per line, two types: `"model_turn"` (one per model
request/response, `request`/`response`/`elapsed_s`) and `"tool_result"`
(one per tool execution, `tool`/`arguments`/`response`/`elapsed_s`).
`"tool_result"`'s `response` is the canary wire body verbatim — exactly
`serialize_eval`'s or `serialize`'s shape
(`docs/reference/wire-protocol.md`), never reformatted or summarized:

```json
{"type":"tool_result","turn":1,"tool":"ruby_eval","arguments":{"code":"6 * 7"},"response":{"outcome":"ok","value":{"class":"Integer","inspect":"42","truncated":false},"stdout":"","stderr":"","exception":null,"request_id":null},"elapsed_s":0.014}
```

## Prove the shape offline

`test/canary/tool_loop/scripted_gateway.rb` is a fake `/v1/chat/completions`
server that serves a named, canned sequence of responses instead of a real
model — bootable standalone the same way `bin/canary-server` is:

```console
bundle exec ruby -Ilib test/canary/tool_loop/scripted_gateway.rb --port 9402 --script eval-then-tests-then-final
```

Point `bin/canary-tool-loop --base-url http://127.0.0.1:9402/v1 --model scripted`
at it, alongside a real `bin/canary-server`, to walk the loop's full
machinery (turn counting, real tool dispatch, transcript, termination)
without spending on a live model call. `test/canary/tool_loop_test.rb`
exercises the same thing in-process, against real bound sockets for both
edges (no mocking either collaborator).

## What this is not

- **Non-streaming only.** Every request sends `stream` absent (false).
  Streaming tool-call delta assembly is unexercised and out of scope for
  this loop.
- **Not a measurement.** `run_tests` hands the model the grader's own
  pass/fail signal — a strictly stronger channel than hidden-mode sampling
  (`Canary::Prompt`'s default), which never reveals whether an answer
  passed. Nothing here computes or claims a pass@k, a scoring comparison,
  or any other benchmark number; this is plumbing proof that the loop
  walks the real wire end to end, not a measurement of model capability.
