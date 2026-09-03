# Reference: public API map

Everything `require "canary"` loads (`lib/canary.rb`), in load order. Each
file carries its own doc comment; this is the index.

| constant | file | what it is |
|---|---|---|
| `Canary::VERSION` | `lib/canary/version.rb` | gem version string. |
| `Canary::RolloutResult`, `Canary::ExampleResult` | `lib/canary/rollout_result.rb` | the structured outcome of one rollout, and one graded example within it. |
| `Canary::Adapters::MinitestAdapter`, `Canary::Adapters::RSpecAdapter` | `lib/canary/adapters/` | framework-specific runners `Canary::Pool` dispatches to inside the child. |
| `Canary::Pool` | `lib/canary/pool.rb` | forks a child per rollout; the process-isolation boundary. |
| `Canary::Prompt` | `lib/canary/prompt.rb` | renders a `TaskRepo::Entry` into the system prompt and user message. Hidden mode sends the statement only; grader-visible mode adds the grader and is diagnostic. `Prompt::SYSTEM` is the output contract. |
| `Canary::Extractor` | `lib/canary/extractor.rb` | reads the model's answer into one Ruby source: the first Ruby fence, or the whole unfenced answer. `Extractor::ACCEPTED` names the gradable outcomes. |
| `Canary::Task` | `lib/canary/task.rb` | `{solution_path, test_path, adapter}`, what `Pool#rollout_task` runs. |
| `Canary::TaskRepo`, `::Entry`, `::BrokenSolution` | `lib/canary/task_repo.rb` | loads `tasks/**` and validates provenance at load time. |
| `Canary::Verifier` | `lib/canary/verifier.rb` | composes `Canary::Prefilter` and `Canary::Pool` into one call per task. |
| `Canary::Prefilter` | `lib/canary/prefilter.rb` | static, non-executing checks (Prism parse, opt-in RuboCop Lint) ahead of a rollout; also the truncation detector. Required by `verifier.rb`. |
| `Canary::Providers::Anthropic` | `lib/canary/providers/anthropic.rb` | live provider wrapping the `anthropic` gem. |
| `Canary::Providers::OpenAICompat` | `lib/canary/providers/openai_compat.rb` | live provider for any OpenAI-compatible chat-completions endpoint, hosted or local. States temperature and a prompt-derived seed on every request; per-instance read timeout; per-model extra body fields; an `on_request` hook that lets the sampler record the exact body sent. |
| `Canary::Providers::Fake` | `lib/canary/providers/fake.rb` | in-test stand-in. |
| `Canary::Sampler`, `::Budget`, `::SpendGuard`, `::RecordSink` | `lib/canary/sampler.rb` | drives a provider under a request-count budget and an optional dollar cap; `RecordSink` appends request and response to `completions.jsonl`. |
| `Canary::Eval::Record` | `lib/canary/eval/record.rb` | one row per (task, model, sample); see [sweep-record-schema.md](sweep-record-schema.md). |
| `Canary::Eval::Report` | `lib/canary/eval/report.rb` | aggregates records into `pass@k`, non-score breakdowns and timing, non-scores kept out of every denominator. |
| `Canary::Eval::Runner` | `lib/canary/eval/runner.rb` | render → sample → extract → verify under a bounded `Async::Semaphore`, sample-major, stamping `sample_ms`. Owns `SCHEMA_VERSION`. |
| `Canary::Server`, `::Auth`, `::Config` | `lib/canary/server.rb`, `lib/canary/server/` | the `POST /v1/rollouts` wire surface; see [wire-protocol.md](wire-protocol.md). |

Three executables under `bin/` are not part of `require "canary"`:

| script | what it does |
|---|---|
| `bin/eval_sweep.rb` | the `EvalSweep` module: model lists, provider routing, pricing, request shaping, and the corpus sweep itself. [How-to](../how-to/run-a-sweep.md). |
| `bin/rescore.rb` | the `Rescore` module: re-grades committed runs against the current extractor into sidecar files. [How-to](../how-to/rescore-a-run.md). |
| `bin/canary-server` | boots `Canary::Server` on a loopback socket. [How-to](../how-to/run-the-server.md). |
