# Contamination

What this project can and cannot claim about whether the models it evaluates
have seen this corpus before. Written to be checked, not taken on faith —
every claim below names the file or artifact it's checked against.

## Provenance

Every task in `tasks/**` (`Canary::TaskRepo.all.size` is the current count)
is **authored**, not sourced from any public
corpus. This is the strongest true contamination claim this project can
make, and it's worth stating plainly rather than dressing it up: every
task's natural-language statement, its reference solution, its
deliberately-broken solutions, and the grading test file that scores all of
them were written from scratch for this project. None of it is copied or
adapted from an existing published exercise, tutorial, blog post, or
benchmark suite.

This is now a checkable fact, not just an assertion. Every `tasks/*/meta.yml`
carries `provenance: authored`, surfaced as `Canary::TaskRepo::Entry#provenance`
(`lib/canary/task_repo.rb`), and `Canary::TaskRepo.all.all? { |e| e.provenance
== "authored" }` is true today (`test/canary/task_repo_test.rb`,
`test_todays_corpus_is_entirely_authored_with_no_attestation`). The corpus's
own git history backs this too: every commit that touches `tasks/**` is a
`lane corpus: integrate` commit authoring a new task directory; none imports
or adapts code from another repository.

`#provenance` also accepts `"sourced"`, and a sourced task must carry a
`#source_attestation` (a training-data cutoff statement) — enforced at load
time: `Canary::TaskRepo#load_task` raises `ArgumentError` for a `sourced` task
with a blank attestation, for every caller that loads the corpus, not just a
test that happens to check it. Today this is inert — there are no sourced
tasks — but the point isn't today's task count. It's that the corpus cannot
grow a sourced task later without someone stating, in writing, what training
cutoff that task is claimed to postdate. An authored-only corpus makes no
claims that need checking here; a sourced one would, and now can't skip that
step.

## Held-out posture

Two distinct senses of "held out" apply, and they shouldn't be conflated.

**Held out from the model at sample time.** `Canary::Prompt.render`
(`lib/canary/prompt.rb`) is the only surface a model ever sees, and its
hidden mode — the default — sends the model exactly one thing:
`entry.statement`. Never the category, never a broken solution's id or
misconception, never the grader. Grader-visible mode is opt-in and
diagnostic only; it additionally reveals the grader test file, but still
never the reference solution or any broken solution's misconception. This is
structural, not a filter that could be bypassed by a new field: every
private builder in `Prompt` takes only bare strings, never the `Entry`
itself, so nothing added to `Entry` — including the provenance fields this
lane adds — can reach a prompt through that class. This is proven, not just
argued: the `no-mechanism-leak` gate and `test/canary/prompt_test.rb`'s
`test_hidden_mode_leaks_no_entry_field_other_than_statement` (which reflects
over every `Entry` member — `provenance` and `source_attestation` included,
now real `Struct` members rather than fields reachable only through an
attr_reader outside `Entry.members`'s view — and asserts none of it appears
in hidden-mode text) both pass with this lane's changes in place. What this buys: a model
answering hidden mode cannot be pattern-matching against the grader or the
misconception catalogue built for it — that content genuinely never reaches
it. What it does not buy: any claim that the model hasn't seen semantically
similar *tasks* elsewhere — see the next section.

**Held out from public exposure.** The corpus is authored, not scraped (see
Provenance), so nothing in it is derived from a crawlable source. This repo
has a GitHub remote configured (`origin` → `git@github.com:jetpks/canary.git`)
but whether or when that remote goes public, and what if anything is
currently pushed there, is **not verified by this lane** — checking would
require a live network call to GitHub, which is out of scope for an offline,
zero-spend lane. Treat the corpus's exposure to public crawls and web
indexes as an open question, not a settled "never crawled" claim.

Neither of these covers what happens once a task is actually *sent* to a
model for scoring, live — that's a separate concern, addressed next.

## Burned repositories

"What has this project already put into a model's context" has two
different, non-interchangeable answers depending on what's being asked.

**External repositories fed to a model to help build this corpus: nothing
yet.** No external codebase's content was given to a model as raw material
for authoring the tasks in `tasks/**`. The corpus's git history (`lane corpus:
integrate` commits) shows tasks being authored directly, not derived from
another repository's content run through a model first.

**This project's own corpus content sent to a live model: not "nothing
yet."** `results/sweep.jsonl` (I15's sweep, committed at base `6add1f8`) is
on disk and countable: 91 records total, all 13 tasks' hidden-mode
statements sent to both `claude-haiku-4-5-20251001` and `claude-sonnet-5` (39
hidden-mode records each), plus all 13 tasks' full `grader.rb` source sent in
grader-visible mode to `claude-haiku-4-5-20251001` (13 records) — for
$0.3029 spent (`results/summary.md`). Reference solutions, broken solutions,
and misconception text were never sent in either mode, because
`Canary::Prompt.render` never reads them.

What that costs: once a task's statement (and, for the grader-visible arm,
its full grader) has been sent to a commercial model's inference endpoint,
this project no longer controls what happens to that content afterward —
whether it's retained, logged, reviewed, or folded into a future training
run is governed by the provider's data-usage terms, not by anything in this
codebase. `lib/canary/providers/anthropic.rb` makes a plain
`@client.messages.create` call with no data-usage opt-out configured, and
`lib/canary/providers/openai_compat.rb` (routing to OpenRouter and
Fireworks in `bin/eval_sweep.rb`'s configured model set) offers no opt-out
either. This does not retroactively contaminate I15's scores against
`claude-haiku-4-5-20251001`/`claude-sonnet-5` — those models' training
predates this corpus's existence by construction, since it was authored
after they shipped. But the picture is broader than that one run now: every
task's hidden-mode statement — and, for the Anthropic anchors, the
visible arm's full graders too — has crossed commercial inference
endpoints in every sweep committed under `results/` since, not just I15's.
This corpus cannot be treated as guaranteed-unseen by any of those
providers' infrastructure for a model trained after the dates those runs
happened.

This lane itself made zero live calls (see its `run.jsonl`) and adds nothing
to this list; the fact above predates it.

## What we claim and what is unknowable

**Claimed:**

- These tasks' specific text — statement, solutions, graders,
  misconceptions — was written for this project, not copied from an
  existing published source (Provenance).
- Hidden-mode prompts structurally cannot contain the grader, a
  misconception, or a category (Held-out posture, proven by the
  `no-mechanism-leak` gate and `test/canary/prompt_test.rb`).

**Unknowable, and why:**

- **Whether the underlying *ideas* are novel.** We cannot verify this, and
  we don't claim it. "A memoizer using `||=` recomputes a falsy result",
  "`Comparable` gives `==` but not `eql?`/`hash`", "a bare constant shadows
  `Math::PI`" — these are common Ruby gotchas that plausibly appear, in some
  form, in blog posts, style guides, or Rosetta-Code-style snippets that
  predate this corpus and that a model may have trained on. Authored
  *wording* is not the same as a novel underlying *concept*. We make no
  claim that the concepts here are original, only that this specific
  text/code was written for this project.
- **Any specific model's training-data cutoff.** We don't have a verified
  cutoff date for any model this project evaluates. "This corpus postdates
  that cutoff" is an inference from the corpus's creation date, not a
  proven fact about any model's training set.
- **What happens to API traffic after it's sent.** Per Burned repositories,
  we cannot see or verify whether a provider logs, reviews, or trains on
  prompts submitted for scoring. This is outside this project's visibility
  entirely.
- **This repo's public/crawl status.** Per Held-out posture, whether
  `github.com/jetpks/canary` is public and has been crawled is not checked
  by this lane and is not asserted either way.

Given all of that, the strongest defensible claim this project can make is:
**these tasks' specific text was not copied from an existing published
source, and the harness withholds the grader and misconception catalogue
from the model at sample time.** Not that the underlying tasks are
conceptually novel. Not that no model has ever seen anything resembling
them. Not that this corpus is guaranteed unseen by any particular model. An
honest "we cannot verify X" here is worth more than a confident sentence a
reviewer can break by asking one follow-up question.

## Reasoning traces

`Canary::Sampler#payload_for` (`lib/canary/sampler.rb`) records a thinking-
enabled model's full raw response verbatim, by design — the same policy
that keeps a truncated response's complete text on disk (I14 F1) doesn't
carve out an exception for `thinking` content blocks. The fixture
`test/canary/sampler_fixtures/responses/thinking_and_text.json` is a real
captured example: it carries a `content` block with `"type": "thinking"` and
a `signature` field (an opaque, provider-issued token) alongside the final
`"type": "text"` answer. A parallel lane is committing these records —
including thinking blocks and signatures — to `results/` as a published,
version-controlled artifact.

**This is a publication decision that needs to be made, not discovered by
whoever opens a record file first.** Three options, and why we're not
picking one for you:

- **A. Ship the raw records as-is.** Simplest; preserves the fullest
  possible audit trail, including for research into whether a model's
  visible reasoning references memorized content — plausibly the single
  most useful signal this project could offer a future contamination study.
  Cost: `signature` is opaque provider-internal plumbing whose only real use
  is round-tripping the block back to the API; publishing it leaks an
  implementation detail with no reader-facing value and no guarantee of
  format stability across provider versions. In the one fixture on disk,
  the `thinking` field's actual text content is empty (`"thinking": ""`) —
  so in practice, what would ship here today is the signature and an empty
  string, not necessarily the readable reasoning most people picture when
  they hear "reasoning trace."
- **B. Strip `thinking` blocks and signatures before writing to disk at
  all.** Cost: this conflicts with a frozen requirement one level up — AC5's
  "a run you cannot re-score is a run you have to re-buy" demands the raw
  provider response be persisted for re-scoring. Stripping at write time
  would mean re-buying a live sample just to recover reasoning content this
  project chose to throw away the first time.
- **C. Keep the raw completions artifact as AC5 requires, and decide
  separately, at publication time, whether a public-facing copy strips
  `thinking`/`signature` blocks before it leaves this project's control.**

**Recommendation: C.** It's the only option that doesn't conflict with AC5,
and it correctly treats "record everything for internal re-scoring" and
"what goes out under this project's name" as two different decisions made
at two different times. Given that the one real fixture already ships an
empty `thinking` string with a real `signature`, the actual risk from
shipping as-is looks smaller than "leaking a model's private reasoning" and
closer to "publishing an opaque, provider-versioned token for no reader
benefit, before anyone has decided whether that's this project's call to
make." That decision belongs to the human, not to whichever lane happens to
commit the artifact first.
