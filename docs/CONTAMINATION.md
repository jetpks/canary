# Contamination

What this project can and cannot claim about whether the models it evaluates
have seen this corpus before. Written to be checked, not taken on faith —
every claim below names the file or artifact it's checked against.

## Provenance

The corpus partitions into two provenance classes, declared per task in
`meta.yml` and validated at load time by `Canary::TaskRepo#load_task`
(`lib/canary/task_repo.rb`). The split is checkable, not asserted:
`test/canary/task_repo_test.rb`'s
`test_the_corpus_partitions_cleanly_between_authored_and_sourced_provenance`
holds it on every run.

**`authored`** — statement, reference solution, broken solutions, and grader
all written from scratch for this project, not copied or adapted from a
published exercise, tutorial, post, or benchmark suite. An authored task
carries no `source_attestation`, and the test asserts that.

**`sourced`** — adapted from external material, and required to carry a
non-blank `source_attestation` naming that material and the training cutoff
it claims to postdate. `load_task` raises `ArgumentError` for a `sourced`
task with a blank or missing attestation — for every caller that loads the
corpus, not just a test that checks for it.

Every sourced task in the corpus today is adapted from a merged
`rails/rails` pull request, and the partition test asserts that citation
form specifically. Each attestation states its own limit rather than
claiming cleanliness: the cited PR postdates Anthropic's publicly
documented training-data cutoffs, which makes "unseen by an Anthropic
model" a strong heuristic and not a guarantee; for every other model, no
cutoff is verifiable from public information at all.

## Held-out posture

Two distinct senses of "held out" apply, and they shouldn't be conflated.

**Held out from the model at sample time.** `Canary::Prompt.render`
(`lib/canary/prompt.rb`) is the only surface a model ever sees, and its
hidden mode — the default — sends the model exactly one thing:
`entry.statement`. Never the category, never a broken solution's id or
misconception, never the grader. Grader-visible mode is opt-in and
diagnostic only; it additionally reveals the grader test file, but still
never the reference solution or any broken solution's misconception. This is
structural, not a filter a new field could slip past: every private builder
in `Prompt` takes bare strings, never the `Entry` itself, so nothing added
to `Entry` can reach a prompt through that class.
`test/canary/prompt_test.rb`'s
`test_hidden_mode_leaks_no_entry_field_other_than_statement` proves it by
reflecting over every `Entry` member — `provenance` and
`source_attestation` included, both real `Struct` members — and asserting
none of it appears in hidden-mode text. What this buys: a model answering
hidden mode cannot be pattern-matching against the grader or the
misconception catalogue built for it, because that content never reaches
it. What it does not buy: any claim that the model hasn't seen semantically
similar *tasks* elsewhere — see the next section.

**Held out from public exposure.** Authored tasks are written here, not
scraped, so nothing in them derives from a crawlable source. Sourced tasks
do not get that claim: each is adapted from a public `rails/rails` pull
request, crawlable by construction — what stands behind them is the merge
date in their attestation, not obscurity. Separately, this repo has a
GitHub remote configured (`origin` → `git@github.com:jetpks/canary.git`);
whether that remote is public, and what if anything is pushed there, is not
verified anywhere in this repo. Treat the corpus's own exposure to crawls
and indexes as an open question, not a settled "never crawled" claim.

Neither of these covers what happens once a task is actually *sent* to a
model for scoring, live — that's a separate concern, addressed next.

## Burned repositories

"What has this project already put into a model's context" has two
different, non-interchangeable answers depending on what's being asked.

**External material used to build this corpus.** Authored tasks were
written directly, not derived from another repository's content. Sourced
tasks were: each is adapted from a named `rails/rails` pull request, so
public upstream code is raw material for that slice of the corpus. Which
upstream that is, is stated per task in its `source_attestation` and
traceable to the PR it cites.

**This project's own corpus content sent to a live model.** Every hosted
sweep under `results/` sent each task's hidden-mode statement to a
commercial endpoint, and for the two Anthropic anchors the grader-visible
arm sent each task's full `grader.rb` as well. The hosted runs happened between
2026-08-03 and 2026-08-05, when the corpus was 34 tasks. The ten tasks
added since have only ever been sent to models served on owned hardware:

```text
credits_reel_contributor_chain        mood_board_owned_swatches
delivery_audited_route_block          reading_circle_member_enumeration
event_broadcaster_duck_protocol       shipment_alert_recipient_protocol
expense_tracker_injected_rounding     shipping_quote_polymorphic_packages
tallying_key_store_fetch_contract     temperature_report_injected_scale
```

The split is countable from the committed records: list the distinct
`task_name`s in the hosted runs' `sweep.jsonl` and subtract them from
`tasks/`. Reference solutions, broken solutions and misconception text
were never sent in either mode, because `Canary::Prompt.render` never
reads them.

What that costs: once a task's statement, or in the grader-visible arm its
grader, reaches a commercial inference endpoint, this project no longer
controls what happens to it. Retention, logging, review, or folding into a
future training run is governed by the provider's data-usage terms, not by
anything here. `lib/canary/providers/anthropic.rb` makes a plain
`messages.create` call with no data-usage opt-out configured, and
`lib/canary/providers/openai_compat.rb` offers none either.

This does not retroactively contaminate scores against the models that
were run: they shipped before the corpus was written. But the 34 tasks
that crossed a hosted endpoint cannot be treated as guaranteed-unseen by
those providers' infrastructure for any model trained after August 2026.

Locally-served runs are the exception, and the reason the hosted/local
distinction is worth keeping. Every run since 2026-08-15, and every run in
the Canary Register, was served on owned hardware through the `:studio`
provider kind; those prompts never left the machine and add nothing to the
exposure above.

## What we claim and what is unknowable

**Claimed:**

- Every task declares its provenance, and the declaration is enforced at
  load time. Authored tasks' text — statement, solutions, graders,
  misconceptions — was written for this project, not copied from a
  published source. Sourced tasks are adapted from the dated `rails/rails`
  pull request each one cites (Provenance).
- Hidden-mode prompts structurally cannot contain the grader, a
  misconception, or a category (Held-out posture, proven by
  `test/canary/prompt_test.rb`).

**Unknowable, and why:**

- **Whether the underlying *ideas* are novel.** We cannot verify this, and
  we don't claim it. "A memoizer using `||=` recomputes a falsy result",
  "`Comparable` gives `==` but not `eql?`/`hash`", "a bare constant shadows
  `Math::PI`" — these are common Ruby gotchas that plausibly appear, in some
  form, in blog posts, style guides, or Rosetta-Code-style snippets that
  predate this corpus and that a model may have trained on. Authored
  *wording* is not the same as a novel underlying *concept*. We make no
  claim that the concepts here are original — only that authored text was
  written for this project, and that sourced text names where it came
  from.
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
  anywhere in this repo, and is not asserted either way.

The strongest defensible claim is therefore: **every task declares where it
came from, authored text was not copied from a published source, sourced
text names the dated upstream it was adapted from, and the harness withholds
the grader and misconception catalogue from the model at sample time.** Not
that the underlying ideas are novel. Not that no model has seen anything
resembling them. Not that this corpus is guaranteed unseen by any particular
model.

## Reasoning traces

`Canary::Sampler#payload_for` (`lib/canary/sampler.rb`) records each
provider's full raw response verbatim, by design: the policy that keeps a
truncated response's complete text on disk carves out no exception for
reasoning content. Committed runs under `results/` therefore carry whatever
reasoning a provider returned, in whatever shape it returned it — and the
two shapes on disk today differ enormously in what they actually contain.

**Anthropic `thinking` blocks — signatures, no reasoning.** 506 blocks
across 7 committed `completions.jsonl` files. Every one carries a
non-empty `signature`, an opaque provider-issued token whose only use is
round-tripping the block back to the API, and every one carries an
*empty* `thinking` string. What ships here is the token, not the
reasoning.

**OpenAI-compatible `reasoning` / `reasoning_content` — the real thing.**
As of 2026-09-03: 4 097 records across 35 committed files, spanning 26
models, carrying about 27.6 million characters of readable model
reasoning; the longest single trace is about 113 000 characters. These
are verbatim chains of thought. Most local arms were run with reasoning
suppressed and contribute nothing here; the bulk comes from the hosted
reasoning models and from the arms where suppression was partial or
deliberately off.

Recount from a checkout with:

```console
ruby -rjson -e 'n=c=0; Dir.glob("results/**/completions.jsonl").each { |f| File.foreach(f) { |l| m = (JSON.parse(l) rescue {}).dig("response","choices",0,"message") or next; t=(m["reasoning"]||m["reasoning_content"]).to_s; next if t.empty?; n+=1; c+=t.size } }; puts [n, c].inspect'
```

Recording is settled: raw retention is what makes a run re-scorable without
re-buying it, so stripping at write time would trade the audit trail for
nothing. Publication is a separate question, and it is presently answered by
default — the traces are in the repository. Anyone republishing `results/`,
or reading it expecting graded outcomes alone, should know it also carries
tens of millions of characters of model reasoning.
