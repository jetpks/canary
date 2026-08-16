# Explanation: threat boundary

What canary's sandbox does and does not defend against, and why. This is the
full accounting the README's "What this is not yet" section points to.

## The sandbox is not hardened

Rollouts run in a forked child process, not a sandboxed or contained one.
`test/canary/tamper_test.rb` is an executable catalogue of
grader-tampering attacks against the current pool: as of this writing, 10
of its 19 named vectors still succeed against the harness (each recorded as
a `skip` naming the vector and what it forges), and 9 are defended by a
real assertion. The hardening iteration turns skips into assertions as each
vector is closed; this file is the up-to-date source of truth for which is
which.

## Four accepted, documented classes of the same underlying limit

canary's rollout relay (`Pool#fork_and_collect`/`#relay`,
`lib/canary/pool.rb`) defends the reported verdict against a submission
that corrupts the wire's *shape* (extra objects, malformed bytes) but does
not and cannot fully defend against a submission that corrupts the wire's
*timing*:

1. **Wire-timing forge-and-exit.** A submission that constructs one
   legitimately-shaped, falsely-valued result and exits before the harness's
   own honest write ever runs is indistinguishable, byte-for-byte, from a
   real result
   (`test/canary/tamper_fixtures/forge_and_exit_submission.rb`).
2. **Self-owned `method_missing` interception.** A submission that
   intercepts its own assertion dispatch through `method_missing` on a
   class it legitimately owns
   (`test/canary/tamper_fixtures/method_missing_assert_submission.rb`).
3. **Filesystem side effects invisible to the reported result.** Fork
   isolates memory, not disk
   (`test/canary/tamper_fixtures/writes_file_submission.rb`,
   `rspec_writes_file_submission.rb`).
4. **Direct reopening of the trusted assertion/verdict classes themselves.**
   A `Module#freeze` counter on those classes was tried and rejected — a
   bypass probe showed subclass-override, `Minitest::Test.prepend`, and
   include-into-subclass all defeat it, so it closes the fixtures' exact
   syntax, not the capability.

All four vector classes — wire-timing forge-and-exit, self-owned
`method_missing` interception, filesystem side effects, and trusted-class
reopen — are accepted, documented limits of process-fork isolation on a
single machine, not gaps the relay's wire protocol can close by itself; no
counter to any of them is claimed anywhere in this repo. Closing them for
real requires OS-level sandboxing or off-process verdict verification, both
explicitly out of this component's scope.

## What is actually defended

The wire-*shape* attacks the relay does close, with a real regression
assertion each: a hijacked pipe carrying a second forged object alongside
the real one (`test_pipe_hijack_does_not_reach_the_parent`), non-Marshal
garbage on the wire (`test_writing_non_marshal_bytes_onto_the_wire_is_reported_not_raised`),
`const_missing` hooked on `Object` to intercept every reference site in the
process (defended for the scoped case, an open vector for the object-wide
case — see `test/canary/tamper_test.rb` directly for the current split),
vacuous suites that would otherwise pass by running zero examples, exiting
before any assertion runs, coverage corruption that would otherwise destroy
a genuine pass, and a deleted or modified grader file (reported `:invalid`,
never scored).

## `POST /v1/eval` runs arbitrary Ruby with none of `/v1/rollouts`' gates

`POST /v1/eval` (`Canary::Pool#eval_code`) shares `/v1/rollouts`' exact
fork/relay/timeout machinery and process-isolation boundary — everything
above about fork isolating memory, not disk, and about the four accepted
tamper classes, applies to it identically. It is a strictly narrower
surface in one sense (no adapter, no grading, no task context to tamper
with) and a strictly wider one in another: `/v1/rollouts` always runs a
submission through `Canary::Prefilter` first (a Prism parse, and optionally
a RuboCop Lint pass) before it ever reaches a fork; `/v1/eval` has no
prefilter at all, by design: observation is not submission, and gating an
eval the same way a graded submission is gated would misrepresent what the
caller asked for. Every
request to `/v1/eval` runs its exact code in a forked child with no static
check ahead of it, whatever that code does — the same forked-child model
`/v1/rollouts` relies on, offered with one less layer between the caller
and a live Ruby interpreter.

## No containment claim

This work is open and ongoing — nothing in this repo should be read as a
claim that submissions are safely contained. The forked-child model bounds
what an *honest* submission can accidentally do (a runaway loop, a bad
`Timeout`), and it closes several *specific*, *known* forgery mechanisms.
It is not a security boundary against an adversarial submission with full
knowledge of the harness's internals, and this document exists precisely so
that gap stays explicit rather than implied.
