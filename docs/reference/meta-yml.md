# Reference: `meta.yml` keys

Loaded by `Canary::TaskRepo#load_task` (`lib/canary/task_repo.rb`) via
`YAML.load_file(..., symbolize_names: true)`. See
[`../how-to/author-a-task.md`](../how-to/author-a-task.md) for a worked
example and the statement-writing rules.

| key | type | required | notes |
|---|---|---|---|
| `category` | String | yes | free text; a human-facing grouping. Never sent to a model. |
| `adapter` | String, `"minitest"` or `"rspec"` | yes | coerced to a Symbol; selects which grading framework `grader.rb` runs under. |
| `statement` | String | yes | the natural-language task text. The *only* field `Canary::Prompt` sends to a model in hidden mode. |
| `provenance` | String, `"authored"` or `"sourced"` | yes | `"authored"` means written from scratch for this project; `"sourced"` means adapted from an external corpus. `Canary::TaskRepo#validate_provenance!` enforces the value is one of the two. |
| `source_attestation` | String | only if `provenance: sourced` | a training-data-cutoff attestation. Loading raises `ArgumentError` for a `sourced` task with a blank or missing one. Ignored (may be omitted) for `authored`. |
| `broken` | Array of `{id:, misconception:}` | yes | one entry per file expected at `broken/<id>.rb`. `id` names the file (without `.rb`); `misconception` is free-text documentation of the mistake, never sent to a model. |

Every task in the current corpus carries `provenance: authored`; no task
currently sets `source_attestation`.

Reflects into `Canary::TaskRepo::Entry` (`Entry.members`) as
`:name, :category, :statement, :adapter, :reference, :broken_solutions,
:provenance, :source_attestation` — `name` comes from the directory name,
not `meta.yml`; `reference` and `broken_solutions` are built from the fixed
filenames (`solution.rb`, `grader.rb`, `broken/<id>.rb`), not read from
`meta.yml` directly.
