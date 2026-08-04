# How-to: run the server and call `POST /v1/rollouts`

`Canary::Server` (`lib/canary/server.rb`) is a single-shot wire surface: one
verb, one resource, no session. `bin/canary-server` boots it behind a
bearer-token auth middleware on a real socket. Everything below is offline —
no model call, no credential beyond a token you make up yourself, one
locally-graded submission.

## Boot it

`Canary::Server::Config` (`lib/canary/server/config.rb`) reads its
configuration from the environment; `CANARY_SERVER_TOKEN` is required and
never taken as a flag (so it never shows up in `ps`). It binds `127.0.0.1`
by default — never a network-reachable address.

```console
CANARY_SERVER_TOKEN=docs-demo-token CANARY_SERVER_PORT=9293 \
  bundle exec ruby bin/canary-server
```

## Call it

A request body needs `task_name` (must match a `Canary::TaskRepo` entry
name) and `submission_code` (a string of Ruby source); `timeout` and
`coverage` are optional, `request_id` is echoed back verbatim if present.
Auth is `Authorization: Bearer <token>`.

```console
curl -s -X POST http://127.0.0.1:9293/v1/rollouts \
  -H "authorization: Bearer docs-demo-token" \
  -H "content-type: application/json" \
  -d '{"task_name":"struct_vector","submission_code":"Vector = Struct.new(:x, :y, keyword_init: true) do\n  def +(other)\n    Vector.new(x: x + other.x, y: y + other.y)\n  end\nend\n","request_id":"docs-demo-1"}'
```

Observed response (real round trip, `struct_vector`'s own reference solution
as the submission):

```json
{
  "outcome": "ok",
  "passed": true,
  "prefilter": {
    "clean": true,
    "syntax_valid": true,
    "truncated": false,
    "findings": []
  },
  "rollout": {
    "outcome": "ok",
    "passed": 4,
    "failed": 0,
    "total": 4,
    "error": null,
    "examples": [
      {
        "name": "VectorGraderTest#test_adds_two_vectors_componentwise",
        "status": "passed",
        "message": null
      },
      {
        "name": "VectorGraderTest#test_to_h_reflects_members",
        "status": "passed",
        "message": null
      },
      {
        "name": "VectorGraderTest#test_addition_does_not_mutate_either_operand",
        "status": "passed",
        "message": null
      },
      {
        "name": "VectorGraderTest#test_struct_equality_is_value_based_not_identity",
        "status": "passed",
        "message": null
      }
    ]
  },
  "request_id": "docs-demo-1"
}
```

A request with a missing or wrong `authorization` header never reaches the
handler — `Canary::Server::Auth` rejects it first:

```console
curl -s -o /dev/null -w "%{http_code}\n" -X POST http://127.0.0.1:9293/v1/rollouts \
  -H "content-type: application/json" \
  -d '{"task_name":"struct_vector","submission_code":""}'
```

Observed output: `401`.

Full request/response field reference:
[`../reference/wire-protocol.md`](../reference/wire-protocol.md).

## Notes on running it for real

- `bin/canary-server` uses `Async::HTTP::Server` directly, one process, no
  Falcon container/service DSL — the pool's preload cost would otherwise be
  paid once per core for nothing (`bin/canary-server`'s own comment).
- Concurrency is bounded (`Canary::Server::DEFAULT_CONCURRENCY`, matching
  `Canary::Eval::Runner`'s own reasoning): every accepted request forks two
  OS processes for its rollout, so unbounded concurrent connections would
  fork-bomb the host.
- A caller-supplied `timeout` is clamped to `Canary::Server::MAX_TIMEOUT`
  (four times `Canary::Pool::DEFAULT_TIMEOUT`) so a request can't hold a
  fork slot open indefinitely.
