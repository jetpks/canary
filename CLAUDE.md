# canary

Ruby: 4.0.6 via mise (see `mise.toml`). If mise is not activated in the
shell, prefix commands with `mise exec --`.

Docs live under `docs/` (diátaxis layout, index in `docs/README.md`).
`results/` is raw sweep data, never hand-edited; `bin/eval_sweep.rb` writes
it and `bin/rescore.rb` adds sidecars.

## Build

    bundle install

## Test

    bundle exec rake test

Runs every `test/**/*_test.rb` file via Minitest (see `Rakefile`). To run a
single file:

    bundle exec ruby -Ilib -Itest test/canary/pool_failure_test.rb

## Bench

    bundle exec ruby bench/pool/rollout_bench.rb --smoke   # fast sanity check
    bundle exec ruby bench/pool/rollout_bench.rb            # full numbers

    bundle exec ruby bench/mutation/compare.rb
    bundle exec ruby bench/runtime/coverage_bench.rb
    bundle exec ruby bench/runtime/tracepoint_bench.rb
