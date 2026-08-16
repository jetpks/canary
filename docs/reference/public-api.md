# Reference: public API map

Everything `require "canary"` loads (`lib/canary.rb`), in load order. Follow
a link to its own file for the real doc comment.

| constant | file | what it is |
|---|---|---|
| `Canary::VERSION` | `lib/canary/version.rb` | gem version string. |
| `Canary::RolloutResult`, `Canary::ExampleResult` | `lib/canary/rollout_result.rb` | the structured outcome of one rollout, and one graded example within it. |
| `Canary::EvalResult`, `Canary::EvalResult::Value`, `Canary::EvalResult::Raised` | `lib/canary/eval_result.rb` | the structured outcome of one `Pool#eval_code` call, and the bounded stand-ins it carries for the evaluated value and any raised exception. |
| `Canary::Adapters::MinitestAdapter`, `Canary::Adapters::RSpecAdapter` | `lib/canary/adapters/` | framework-specific runners `Canary::Pool` dispatches to. |
| `Canary::Pool` | `lib/canary/pool.rb` | forks a child per rollout or `eval_code` call; the process-isolation boundary. |
| `Canary::Prompt` | `lib/canary/prompt.rb` | renders a `TaskRepo::Entry` into model-facing prompt text (hidden or grader-visible). |
| `Canary::Extractor` | `lib/canary/extractor.rb` | pulls Ruby out of a model's fenced-markdown answer. |
| `Canary::Task` | `lib/canary/task.rb` | `{solution_path, test_path, adapter}` — what `Pool#rollout_task` runs. |
| `Canary::TaskRepo`, `Canary::TaskRepo::Entry`, `Canary::TaskRepo::BrokenSolution` | `lib/canary/task_repo.rb` | loads `tasks/**` into `Task` pairs. |
| `Canary::Verifier` | `lib/canary/verifier.rb` | composes `Canary::Prefilter` and `Canary::Pool` into one call per task. |
| `Canary::Prefilter` | `lib/canary/prefilter.rb` | static, non-executing checks (Prism parse + opt-in RuboCop Lint) ahead of a rollout. Required by `verifier.rb`, not top-level `lib/canary.rb`. |
| `Canary::Providers::Anthropic` | `lib/canary/providers/anthropic.rb` | live provider wrapping the `anthropic` gem. |
| `Canary::Providers::OpenAICompat` | `lib/canary/providers/openai_compat.rb` | live provider for any OpenAI-compatible chat-completions endpoint (OpenRouter, Fireworks). `#sample` is the plain-text seam the sweep path depends on; `#chat` is the tools-and-multi-turn seam `Canary::ToolLoop` drives. |
| `Canary::Providers::ChatTurn`, `Canary::Providers::ChatTurn::ToolCall` | `lib/canary/providers/chat_turn.rb` | the typed success `#chat` returns — the assistant message verbatim plus its tool calls, already parsed. |
| `Canary::Providers::Fake` | `lib/canary/providers/fake.rb` | in-test stand-in provider. |
| `Canary::Sampler`, `Canary::Sampler::Budget`, `Canary::Sampler::SpendGuard`, `Canary::Sampler::RecordSink` | `lib/canary/sampler.rb` | drives a provider for `n` completions per task under a request-count budget and an optional dollar cap; records every dispatch. |
| `Canary::Eval::Record` | `lib/canary/eval/record.rb` | one row per (task, model, sample) — see [`sweep-record-schema.md`](sweep-record-schema.md). |
| `Canary::Eval::Report` | `lib/canary/eval/report.rb` | aggregates a set of `Record`s into `pass@k` and non-score breakdowns. |
| `Canary::Eval::Runner` | `lib/canary/eval/runner.rb` | render → sample → extract → verify, fanned out under a bounded `Async::Semaphore`. |
| `Canary::Server`, `Canary::Server::Auth`, `Canary::Server::Config` | `lib/canary/server.rb`, `lib/canary/server/` | the `POST /v1/rollouts` and `POST /v1/eval` wire surface — see [`wire-protocol.md`](wire-protocol.md). |
| `Canary::ToolLoop`, `Canary::ToolLoop::CanaryClient` | `lib/canary/tool_loop.rb` | drives a chat model through `Providers::OpenAICompat#chat` with `ruby_eval`/`run_tests` bound as OpenAI tools, executing every tool call against a real `bin/canary-server` over loopback HTTP — see [`../how-to/run-the-tool-loop.md`](../how-to/run-the-tool-loop.md). |
| `Canary::LoopBench` | `lib/canary/loop_bench.rb` | runs several `Canary::ToolLoop` conversations concurrently, as fibers in one Async reactor, and summarizes their per-turn latency into `summary.json` — see [`../how-to/measure-turn-latency.md`](../how-to/measure-turn-latency.md). |

Two more live under `bin/`, not `lib/`, and are not part of `require
"canary"`: `bin/canary-server` (boots `Canary::Server` on a real socket) and
`bin/eval_sweep.rb` (the `EvalSweep` module driving a full corpus sweep —
see [`../how-to/run-a-sweep.md`](../how-to/run-a-sweep.md)). A third,
`bin/canary-tool-loop`, boots neither server itself — it drives
`Canary::ToolLoop` against a model edge and a tool edge the caller already
has running (see the how-to above). A fourth, `bin/canary-loop-bench`,
likewise boots neither edge — it drives `Canary::LoopBench` against them
(see [`../how-to/measure-turn-latency.md`](../how-to/measure-turn-latency.md)).
