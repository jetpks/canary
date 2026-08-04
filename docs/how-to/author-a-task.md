# How-to: author a task

A task is a directory under `tasks/`, loaded by `Canary::TaskRepo`
(`lib/canary/task_repo.rb`). This walks the full per-file contract using the
real `tasks/struct_vector/` task as the worked example.

## Directory shape

    tasks/<your_task_name>/
      meta.yml
      solution.rb
      grader.rb
      broken/
        <id_1>.rb
        <id_2>.rb
        ...
        mechanism_free.rb

## `meta.yml`

    category: Struct / Data value semantics and equality
    adapter: minitest
    provenance: authored
    statement: "Implement Vector(x:, y:) as a Struct-based value object with #+ that returns a new Vector whose x and y are the componentwise sums of the operands' x and y - e.g. Vector.new(x: 1, y: 2) + Vector.new(x: 3, y: 4) equals Vector.new(x: 4, y: 6). Neither operand may be modified by the call: after a + b, a and b must still equal their original values. Two Vectors with equal x and y compare as == (without being the same object), and #to_h reflects x and y."
    broken:
      - id: mutates_operands
        misconception: "+ mutates and returns self instead of returning a new Vector, so the operands change under the caller's feet."
      - id: transposed_addition
        misconception: "+ subtracts instead of adds - a copy-paste/sign transposition bug that still returns a fresh, non-mutating Vector."
      - id: mechanism_free
        misconception: "+ mutates and returns self instead of returning a new Vector - the simplest implementation that reads correctly for the addition example alone - same misconception as mutates_operands."

Required keys (`Canary::TaskRepo#load_task` raises on a missing one via
`Hash#fetch`, except where noted):

| key | required | meaning |
|---|---|---|
| `category` | yes | free text; a human-facing grouping, never shown to a model |
| `adapter` | yes | `minitest` or `rspec` — which grading framework `grader.rb` uses |
| `statement` | yes | the *only* field a model ever sees in hidden mode (see "Statement discipline" below) |
| `provenance` | yes | `authored` or `sourced` — see `docs/CONTAMINATION.md` |
| `source_attestation` | only if `provenance: sourced` | a training-data-cutoff attestation; loading raises `ArgumentError` for a `sourced` task with a blank one |
| `broken` | yes | array of `{id, misconception}` — one entry per file under `broken/` |

## `solution.rb`

The reference implementation. Must pass `grader.rb` cleanly.

    Vector = Struct.new(:x, :y, keyword_init: true) do
      def +(other)
        Vector.new(x: x + other.x, y: y + other.y)
      end
    end

## `grader.rb`

The test file — minitest or rspec, matching `adapter` — that scores both
`solution.rb` and every file under `broken/`. It never ships to the model
except in diagnostic grader-visible mode (`Canary::Prompt.render(entry,
grader: true)`), which real sweeps don't use.

    class VectorGraderTest < Minitest::Test
      def test_adds_two_vectors_componentwise
        result = Vector.new(x: 1, y: 2) + Vector.new(x: 3, y: 4)
        assert_equal Vector.new(x: 4, y: 6), result
      end

      def test_addition_does_not_mutate_either_operand
        a = Vector.new(x: 1, y: 2)
        b = Vector.new(x: 3, y: 4)
        _ = a + b
        assert_equal Vector.new(x: 1, y: 2), a
        assert_equal Vector.new(x: 3, y: 4), b
      end
      # ...
    end

## `broken/<id>.rb` — one per named misconception, plus `mechanism_free.rb`

Every `broken:` entry in `meta.yml` needs a matching `broken/<id>.rb` file
that `grader.rb` must fail (not error, not pass vacuously). Two rules the
test suite enforces on every task in the corpus
(`test/canary/task_repo_test.rb`):

- **Discrimination.** Two broken solutions must fail on *different* sets of
  grader examples. Two broken solutions caught by the identical assertion
  haven't actually widened what the grader tests
  (`test_every_task_in_the_corpus_is_proven_both_ways_and_discriminates`).
- **A `mechanism_free.rb` is mandatory.** Every task needs exactly one
  broken solution, at `broken/mechanism_free.rb`, that is the simplest
  plausible implementation a model would write with no knowledge of the
  task's specific trap — and the grader must reject it
  (`test_every_task_carries_a_mechanism_free_broken_solution_that_its_grader_rejects`).
  It's exempt from the discrimination rule above: it's allowed to fail on
  the same examples as another broken solution, since its job is proving a
  mechanism-ignorant answer can't pass, not adding new grader coverage.

Example (`tasks/struct_vector/broken/mechanism_free.rb`):

    Vector = Struct.new(:x, :y, keyword_init: true) do
      def +(other)
        self.x += other.x
        self.y += other.y
        self
      end
    end

## Statement discipline

`entry.statement` is the *entire* surface a model sees in hidden mode —
`Canary::Prompt.render` (`lib/canary/prompt.rb`) never passes the model
`category`, a broken solution's `id`, or its `misconception`, and this is
structural: every private builder in `Prompt` takes bare strings, never the
`Entry` itself, so nothing on `Entry` can leak through it
(`test/canary/prompt_test.rb`'s
`test_hidden_mode_leaks_no_entry_field_other_than_statement` proves this by
reflecting over every `Entry` member). That makes the statement the one
place task-authoring precision matters:

- **State every public method the grader calls.** If `grader.rb` calls
  `Vector.new(x:, y:)`, `#+`, `#==`, or `#to_h`, the statement has to say so
  — a model that never learns `#to_h` is expected can't be faulted for
  omitting it.
- **State constructor arity and keyword names exactly**, matching what
  `grader.rb` actually calls.
- **State every return value the grader asserts on.** "Neither operand may
  be modified" and "compare as `==`" are both asserted in `grader.rb` above,
  so both are in the statement.
- **Name no mechanism and no misconception.** The statement says what the
  method must do, never how a wrong implementation tends to fail. Compare
  `struct_vector`'s statement (says nothing about mutation being a common
  bug) against its `mutates_operands` misconception text (says exactly that)
  — the second never reaches a model.

## Verify it

    bundle exec ruby -Ilib -Itest test/canary/task_repo_test.rb

This is the same file the whole corpus runs through — it proves every
task's reference solution passes, every broken solution fails and
discriminates, and every task carries a valid `mechanism_free.rb`. Observed
output against the current corpus:

    Finished in 7.533673s, 3.0530 runs/s, 72.4746 assertions/s.

    23 runs, 546 assertions, 0 failures, 0 errors, 0 skips

Or run the whole suite (`bundle exec rake test`) — a new task directory
under `tasks/` is picked up automatically by `Canary::TaskRepo.all`, no
registration step required.
