# Reference: wire protocol

`Canary::Server` (`lib/canary/server.rb`), exercised end-to-end in
[`../how-to/run-the-server.md`](../how-to/run-the-server.md). Two verbs, JSON
over HTTP/1.1, no session and no polling: `POST /v1/rollouts` grades a
submission against a task, `POST /v1/eval` runs arbitrary Ruby and reports
what happened. Routing lives in `Canary::Server#call` (a `[method, path]`
lookup); any other method/path is `404`.

## `POST /v1/rollouts`

### Auth

`Canary::Server::Auth` (`lib/canary/server/auth.rb`) sits ahead of the
handler: every request needs `Authorization: Bearer <token>` matching the
server's configured token (`CANARY_SERVER_TOKEN`, set at boot — see
`lib/canary/server/config.rb`). A missing or wrong header gets `401` before
the body is ever parsed.

### Request body (JSON object)

| field | type | required | notes |
|---|---|---|---|
| `task_name` | String | yes | must match a loaded `Canary::TaskRepo::Entry#name`, or the response is `400`. |
| `submission_code` | String | yes | the Ruby source to grade. Non-string is `400`. |
| `timeout` | Number | no | positive, finite seconds. Absent → `Canary::Pool::DEFAULT_TIMEOUT`. Present but non-positive, non-finite (including `NaN`/`Infinity`), or non-numeric → `400`. Present and valid → clamped to `Canary::Server::MAX_TIMEOUT` (4x the pool default). |
| `coverage` | Boolean | no | defaults to `true`; passed straight through to `Canary::Verifier#call`. |
| `request_id` | any JSON value | no | echoed back verbatim in the response, `null` if omitted. Caller's own correlation id — not interpreted. |

A malformed JSON body, or a body that isn't a JSON object, is `400`.

### Response body (JSON object), status `200`

| field | type | notes |
|---|---|---|
| `outcome` | String | `"ok"`, `"error"`, `"crash"`, `"timeout"`, `"invalid"` (from `RolloutResult#outcome`), or `"prefiltered"` if the submission never reached a rollout at all. |
| `passed` | Boolean | overall pass/fail. |
| `prefilter` | Object | `clean` (Boolean), `syntax_valid` (Boolean), `truncated` (Boolean), `findings` (Array — see below). |
| `rollout` | Object or `null` | `null` when `outcome` is `"prefiltered"` (no rollout ran). Otherwise: `outcome`, `passed` (Integer), `failed` (Integer), `total` (Integer), `error` (String or `null`), `examples` (Array of `{name, status, message}`). |
| `request_id` | echoes the request's `request_id`, or `null`. |

A prefilter finding: `{tier, severity, type, message, location, gating}` —
`location` is sanitized to a fixed `submission.rb:<line>:<col>` form
(`Canary::Server#sanitize_location`), never the server's real tempfile path.
`rollout.error` and an example's `message` are scrubbed of the real tempfile
path the same way (`Canary::Server#sanitize_text`). Neither `coverage` data
nor the adapter name ever cross the wire.

### Failure statuses

- `400` — malformed/invalid request, as above. The verifier is never
  reached (`test/canary/server_test.rb`'s `*_never_reaches_the_verifier`
  tests assert this directly).
- `401` — auth rejected, before the body is parsed.
- `500` — an unhandled exception inside `Canary::Server#call`. The body is
  a fixed `{"error": "internal error"}` with no exception class, message,
  or path ever included (`test_an_unexpected_exception_is_500_without_leaking_message_class_or_path`).

### Concurrency

Bounded by `Canary::Server::DEFAULT_CONCURRENCY` (an `Async::Semaphore`,
configurable via `CANARY_SERVER_CONCURRENCY`): every accepted request forks
two OS processes for its rollout, so unbounded concurrent connections would
fork-bomb the host — the same reasoning `Canary::Eval::Runner`'s own
concurrency knob follows.

## `POST /v1/eval`

Runs a bare string of Ruby and reports what happened — no adapter, no
grading, no prefilter (observation is not submission). Stateless and
one-shot: every call is a fresh fork (`Canary::Pool#eval_code`), the same
fork/relay/timeout machinery `POST /v1/rollouts` uses, with no session and
nothing carried between calls.

### Auth

Same `Canary::Server::Auth` bearer check as `/v1/rollouts`, ahead of both
routes: a missing or wrong header is `401` before the body is parsed.

### Request body (JSON object)

| field | type | required | notes |
|---|---|---|---|
| `code` | String | yes | the Ruby source to evaluate. Missing or non-string is `400`. |
| `timeout` | Number | no | identical discipline to `/v1/rollouts`' own `timeout`: positive, finite seconds, absent → `Canary::Pool::DEFAULT_TIMEOUT`, present but invalid → `400`, present and valid → clamped to `Canary::Server::MAX_TIMEOUT`. |
| `request_id` | any JSON value | no | echoed back verbatim, `null` if omitted. |

A malformed JSON body, or a body that isn't a JSON object, is `400`.

### Response body (JSON object), status `200`

| field | type | notes |
|---|---|---|
| `outcome` | String | `"ok"` (evaluated and reported, whatever it evaluated to), `"raised"` (a `StandardError` was raised and caught), `"timeout"`, or `"crash"` (the child died — signal, exit, `exit!`, or a non-`StandardError` such as a `SyntaxError` in `code` — without reporting at all). |
| `value` | Object or `null` | `{class, inspect, truncated}` — non-`null` exactly when `outcome` is `"ok"`. The evaluated object itself never crosses the relay: `class` and `inspect` describe a bounded stand-in built in the child (`Canary::Pool#represent_eval_value`), never the real object. `inspect` is capped at `Canary::Pool::EVAL_VALUE_INSPECT_LIMIT` bytes (8 KiB); `truncated` is `true` when the real `inspect` was longer, or when computing it raised (a submission-defined `#inspect` that itself misbehaves). |
| `stdout`, `stderr` | String | output captured in the child (`$stdout`/`$stderr` are swapped for the life of the eval), each capped at `Canary::Pool::EVAL_OUTPUT_LIMIT` bytes (64 KiB), silently — there is no companion `truncated` flag for output the way there is for `value`. Reported for `"ok"` and `"raised"`. A `"timeout"` or `"crash"` child reports empty strings: the result ships to the parent only on the child's own completion (the relay's Marshal write), and a killed or crashed child never gets there — this is inherent to the relay, not eval-specific. |
| `exception` | Object or `null` | `{class, message}` — non-`null` exactly when `outcome` is `"raised"`. Never the real exception object, and never a backtrace: the wire carries no backtrace field, so there is nothing from it to sanitize. |
| `request_id` | echoes the request's `request_id`, or `null`. |

`code` is evaluated directly (`Kernel#eval`, no tempfile) with an explicit
filename/lineno (`Canary::Pool#run_eval_in_child`), so a raised exception's
backtrace reads a bare `(eval):N`, never this repo's own file layout —
verified live that a bare `eval(code)` instead leaks the interpreter's real
path (`"(eval at /real/path/pool.rb:NNN)"`). Since the wire carries no
backtrace at all, this only matters for what would otherwise be a real
path in server logs or a future backtrace field, not for anything a caller
sees today.

Only a `StandardError` raised by `code` is reported as `"raised"`; a
`SyntaxError` (a `ScriptError`, not a `StandardError`) or any other
non-`StandardError` exception is uncaught in the child and surfaces as
`"crash"` — the same rule `Canary::Pool#run_in_child` already applies to a
rollout submission, kept consistent rather than inventing eval-specific
taxonomy.

### Failure statuses

Same as `/v1/rollouts`: `400` malformed/invalid request (the pool is never
reached), `401` auth rejected, `500` an unhandled exception in
`Canary::Server#call` with a fixed `{"error": "internal error"}` body.

### Concurrency

Shares `Canary::Server::DEFAULT_CONCURRENCY`'s single `Async::Semaphore`
with `/v1/rollouts` — an eval forks the same two OS processes a rollout
does, so the fork-bomb budget is one shared pool across both verbs, not one
per verb.
