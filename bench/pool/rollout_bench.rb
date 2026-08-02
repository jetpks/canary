#!/usr/bin/env ruby
# frozen_string_literal: true

# Measures real per-rollout cost for both adapters, with and without
# Coverage, against a gem-shaped ~20-example submission. Run with --smoke
# for a fast sanity check (tiny N); with no flags for the numbers that
# actually matter.
#
#   bundle exec ruby bench/pool/rollout_bench.rb          # full run
#   bundle exec ruby bench/pool/rollout_bench.rb --smoke  # fast gate check

require_relative "../../lib/canary"
require "etc"

smoke = ARGV.include?("--smoke")
n = smoke ? 5 : 400

FIXTURES = {
  minitest: File.expand_path("fixtures/minitest_submission.rb", __dir__),
  rspec: File.expand_path("fixtures/rspec_submission.rb", __dir__),
}.freeze

EXPECTED_PASSED = 21

# Warm both adapters identically, in the parent, before any measured loop -
# an asymmetric warmup (warming one framework but not the other) rigs the
# comparison in favor of whichever got warmed.
pool = Canary::Pool.new(adapters: %i[minitest rspec])

def measure(pool, adapter:, path:, coverage:, n:)
  # Run once, unmeasured, to shake out one-time per-adapter costs (e.g. the
  # submission's own class definitions being autoloaded) so the timed loop
  # reflects steady-state per-rollout cost.
  pool.rollout(adapter: adapter, submission_path: path, coverage: coverage)

  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  n.times do
    result = pool.rollout(adapter: adapter, submission_path: path, coverage: coverage)

    unless result.error.nil? && result.passed == EXPECTED_PASSED && result.failed.zero?
      raise "measurement invalid: adapter=#{adapter} coverage=#{coverage} " \
            "expected #{EXPECTED_PASSED} passed/0 failed, got " \
            "#{result.passed} passed/#{result.failed} failed error=#{result.error.inspect}"
    end
  end

  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  elapsed / n * 1000.0
end

puts "canary rollout pool bench"
puts "ruby:      #{RUBY_DESCRIPTION}"
puts "platform:  #{RUBY_PLATFORM}"
puts "cores:     #{Etc.nprocessors}"
puts "N:         #{n} (#{smoke ? "smoke" : "full"} run)"
puts "minitest:  #{Gem.loaded_specs["minitest"].version}"
puts "rspec-core: #{Gem.loaded_specs["rspec-core"].version}"
puts "async:     #{Gem.loaded_specs["async"].version}"
puts "one iteration: fork a child, load a #{EXPECTED_PASSED}-example gem-shaped submission, " \
     "run its suite through the adapter, return structured results (+coverage, when enabled)"
puts

rows = []
%i[minitest rspec].each do |adapter|
  [false, true].each do |coverage|
    ms = measure(pool, adapter: adapter, path: FIXTURES.fetch(adapter), coverage: coverage, n: n)
    rows << [adapter, coverage, ms]
    label = coverage ? "with coverage" : "no coverage"
    puts format(
      "adapter=%-8s %-14s %8.3f ms/rollout   (%d/%d examples passed on every iteration, asserted)",
      adapter, label, ms, EXPECTED_PASSED, EXPECTED_PASSED
    )
  end
end

puts
puts "summary:"
rows.each do |adapter, coverage, ms|
  puts format("  %-8s coverage=%-5s %.3f ms", adapter, coverage, ms)
end
