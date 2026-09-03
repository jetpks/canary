# How-to: rescore a run

`bin/rescore.rb` re-grades committed runs against the **current**
`Canary::Extractor` without buying a single new sample. Every run keeps
`completions.jsonl` beside its records, so a change to how an answer is
read is answerable from disk.

```console
bundle exec ruby bin/rescore.rb results/run-20260901T211347Z
bundle exec ruby bin/rescore.rb --all
```

## What it does

For each record whose `extractor_outcome` was a refusal
(`no_fenced_code` or `no_ruby_fence`), it re-reads the model's raw text
from `completions.jsonl`, runs the extractor again, and if the extractor
now accepts the answer, grades it through `Canary::Verifier` exactly as
the sweep would have. Every other record is copied through byte-for-byte,
so an unaffected arm's numbers are provably untouched rather than merely
equal.

It prints one line per run:

```text
  nemotron-3-super               run-20260901T211347Z
    re-graded 83 sample(s); scored 49 -> 131; passed 42 -> 111; pass rate 85.7% -> 84.7%
```

## What it writes

Nothing is overwritten. A rescore lands as a **sidecar** in the run's own
directory:

- `rescore-<utc-stamp>.jsonl` — the full record set, re-graded rows
  replaced, everything else verbatim.
- `rescore-<utc-stamp>.json` — a manifest: which tasks were re-graded,
  scored/passed tallies before and after, and the extractor rule that
  caused it.

A run with no changed records gets no sidecar. The original `sweep.jsonl`
stays byte-identical, so any table can be rebuilt either way and a mixed
reading is always detectable. The register prefers the newest sidecar
when one exists; see [results layout](../reference/results-layout.md).

## When it matters

The extractor changed on 2026-09-01 to accept an unfenced answer as a
submission. Before that, a model that wrote correct Ruby without a
markdown fence was recorded as a refusal and left the denominator, which
flattered exactly the models that struggle with formatting. Measured on
the runs of that day, nemotron-3-super had lost 83 of 132 samples to the
missing fence and 82 of them were valid Ruby. Rescoring fixed the reading
without re-buying the sweep. Run it again after any extractor change, and
read `rescore-*.json` before trusting a rebuilt table.
