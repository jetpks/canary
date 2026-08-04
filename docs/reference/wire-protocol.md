# Reference: wire protocol

`Canary::Server` (`lib/canary/server.rb`), exercised end-to-end in
[`../how-to/run-the-server.md`](../how-to/run-the-server.md). One verb, one
resource, JSON over HTTP/1.1, no session and no polling.

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
