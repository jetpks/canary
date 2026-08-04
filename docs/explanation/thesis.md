# Explanation: the thesis

canary's working thesis is that **Ruby is a tail-generalization canary**: a
model that is actually generalizing, rather than pattern-matching against
memorized solutions, should keep producing working Ruby even in places
where Python or JavaScript training data would let it coast on retrieval
instead. Two properties of Ruby make it suited to measuring that gap, and
they compound rather than working independently.

## Corpus scarcity

There is far less public Ruby than Python or JavaScript for a model to have
trained against. A task phrased in Ruby is less likely to have a
near-identical solved example sitting somewhere in a model's training
corpus than the same task phrased in Python — so a Ruby task is closer to
measuring whether a model can *derive* a correct implementation from a
specification than whether it can *recall* one. This is a claim about
relative corpus size, not an assertion that Ruby code is entirely absent
from any model's training data; the argument is about how much retrieval
can carry a model through, not whether retrieval is possible at all.

## Syntactic permissiveness

Ruby tolerates a wide range of code that is syntactically fine and
semantically wrong. `a.x += b.x; self` compiles and runs exactly as cleanly
as `Vector.new(x: a.x + b.x, ...)` — one mutates its arguments and returns
the wrong object, the other doesn't, and nothing about parsing or running
either one tells you which is which. `Canary::Prefilter`'s own tier
structure makes this concrete: tier 0 (a Prism parse) catches code that
doesn't even parse, and that's *all* it catches — it has nothing to say
about whether parseable code is semantically correct. A model that is
guessing rather than reasoning is more likely to fail *silently* on Ruby —
producing code that looks right, parses clean, and executes without
erroring, but gets the semantics wrong — than in a language where the same
class of mistake would refuse to compile or trip an obvious type error.

That silence is a feature of the instrument, not a defect in it. It is
exactly the failure mode a shallow pattern-matcher should produce, and an
eval that only checked "did it crash" would miss it entirely. This is the
whole reason canary's tasks are graded by running a real test suite against
the submission (`Canary::Pool`, `Canary::Verifier`) rather than by static
analysis or a language model's own judgment of the code: only actually
executing the grader's assertions distinguishes "parses and runs" from
"parses, runs, and is correct."

## Probe, not finding

This is a thesis the project is built to probe, not a finding it has
established. Nothing in this repository claims to have confirmed it:

- `results/` holds committed raw sweep artifacts — real dispatches to real
  models, real `Canary::Eval::Record` data — but no leaderboard and no
  citable pass-rate claim is published anywhere in this repo. The artifacts
  are data to look at, not a conclusion to cite.
- The corpus itself is small (`Canary::TaskRepo.all.size` is the current
  count) and hand-authored, not sampled from a larger distribution in any
  statistically representative way. It is a probe, not a benchmark.
- The corpus's own contamination posture is openly qualified, not asserted
  clean — see [`../CONTAMINATION.md`](../CONTAMINATION.md) for exactly what
  can and can't be claimed about whether the models this project evaluates
  have already seen this material.

If the hypothesis is right, a model that's actually generalizing should
show a smaller gap between its Ruby performance and its Python/JS
performance on comparable tasks than a model that's mostly pattern-matching
would. Measuring that gap — carefully, without overclaiming — is what the
rest of this project exists to do.
