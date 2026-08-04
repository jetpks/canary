# Tutorial: install, run the suite, run one rollout

Every command below was run against a clean checkout to produce the output
shown. None of it touches a network or spends anything.

## 1. Install

    bundle install

    Bundle complete! 2 Gemfile dependencies, 50 gems now installed.
    Use `bundle info [gemname]` to see where a bundled gem is installed.

## 2. Run the test suite

    bundle exec rake test

    Finished in 22.179825s, 10.0993 runs/s, 63.9771 assertions/s.

    224 runs, 1419 assertions, 0 failures, 0 errors, 13 skips

The run/assertion/skip counts grow as the corpus and suite grow; the number
that matters is `0 failures, 0 errors`.

To run one file instead of the whole suite:

    bundle exec ruby -Ilib -Itest test/canary/pool_failure_test.rb

## 3. Run one offline, in-process rollout

The suite above proves the harness works. This step shows *how* it works,
one call at a time: load the corpus, pick a task, run its reference solution
through `Canary::Verifier`, and look at the real result — no model, no
network, no forked-off test runner other than the one `Canary::Pool` starts
itself.

    bundle exec ruby -Ilib -e '
    require "canary"

    entry = Canary::TaskRepo.all.find { |e| e.name == "struct_vector" }
    result = Canary::Verifier.new.call(entry.reference)

    puts "passed: #{result.passed}"
    puts "prefilter clean: #{result.prefilter_report.clean?}"
    puts "rollout outcome: #{result.rollout_result.outcome}"
    puts "examples: #{result.rollout_result.passed}/#{result.rollout_result.total} passed"
    '

Observed output:

    passed: true
    prefilter clean: true
    rollout outcome: ok
    examples: 4/4 passed

What happened, in order (see `lib/canary/verifier.rb`):

1. `Canary::TaskRepo.all` loaded every `tasks/**` directory into an `Entry`;
   `entry.reference` is a `Canary::Task` pointing at `struct_vector`'s
   `solution.rb` and `grader.rb`.
2. `Canary::Verifier#call` ran `Canary::Prefilter` against `solution.rb`
   first — a static Prism parse, no execution. It came back clean, so the
   verifier went on to a real rollout.
3. `Canary::Pool#rollout_task` forked a child process, loaded `solution.rb`
   and `grader.rb` into it, ran the grader's Minitest suite against the
   solution, and reported the result back over a pipe — 4 examples, 4
   passed, outcome `:ok`.

Swap `"struct_vector"` for `entry.broken_solutions.first.task` to watch the
same path report a failure instead of a pass — see
[`how-to/author-a-task.md`](how-to/author-a-task.md) for what a broken
solution actually looks like.

From here: [author a task](how-to/author-a-task.md), [run a sweep against a
real model](how-to/run-a-sweep.md), or [run the wire
server](how-to/run-the-server.md).
