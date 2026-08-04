#!/usr/bin/env ruby
# frozen_string_literal: true

# Measures whether a parent-side GC.start / Process.warmup, called once right
# after preload, moves per-rollout cost under today's child-side
# Coverage.start placement (lib/canary/pool.rb is not touched by this bench;
# the "warmup" arms are applied to the bench's own process after constructing
# the pool).
#
# GC.start and Process.warmup are one-way global mutations, so two arms
# cannot share a process - each (round, adapter, arm) runs as its own
# subprocess. Arms are interleaved and order-alternated across rounds
# (rotating through every arm permutation) to rule out the position-in-process
# confound documented in bench/pool/rollout_bench.rb. Run with --smoke for a
# fast sanity check (tiny N, one round); with no flags for the numbers that
# actually matter.
#
#   bundle exec ruby bench/pool/warmup_bench.rb          # full run
#   bundle exec ruby bench/pool/warmup_bench.rb --smoke  # fast gate check

require_relative "../../lib/canary"
require "etc"
require "json"
require "tempfile"
require "rbconfig"

ARMS = %i[none gc warmup].freeze
ADAPTERS = %i[minitest rspec].freeze
FIXTURES = {
  minitest: File.expand_path("fixtures/minitest_submission.rb", __dir__),
  rspec: File.expand_path("fixtures/rspec_submission.rb", __dir__),
}.freeze
EXPECTED_PASSED = 21
SELF_PATH = File.expand_path(__FILE__)

def arg(name)
  match = ARGV.find { |a| a.start_with?("--#{name}=") }
  match&.split("=", 2)&.last
end

# Applies +arm+'s one-time treatment to the current (parent) process, timed
# separately from the rollout series below it - the report needs the
# treatment's own cost as well as its effect on what follows.
def apply_arm(arm)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  case arm
  when :gc then GC.start
  when :warmup then Process.warmup
  when :none then nil
  else raise ArgumentError, "unknown arm #{arm.inspect}"
  end
  (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0
end

# Runs in its own process (see --worker below). Constructs the pool, applies
# the arm, then times +n+ individually-timed covered rollouts. Nothing after
# the arm is discarded: whether its effect is transient or persistent is
# exactly what the first-N/steady-state split in the orchestrator needs to
# see.
def run_worker(arm:, adapter:, n:)
  pool = Canary::Pool.new(adapters: [adapter])
  treatment_ms = apply_arm(arm)
  path = FIXTURES.fetch(adapter)

  # Unmeasured, to shake out the fixture's own one-time costs (autoloaded
  # constants etc.) - the same reason rollout_bench.rb does this - so the
  # timed series below reflects steady-state per-rollout cost, not fixture
  # cold-start noise unrelated to the arm under test.
  pool.rollout(adapter: adapter, submission_path: path, coverage: true)

  series = Array.new(n) do
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = pool.rollout(adapter: adapter, submission_path: path, coverage: true)
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0

    unless result.error.nil? && result.passed == EXPECTED_PASSED && result.failed.zero?
      raise "measurement invalid: arm=#{arm} adapter=#{adapter} " \
            "expected #{EXPECTED_PASSED} passed/0 failed, got " \
            "#{result.passed} passed/#{result.failed} failed error=#{result.error.inspect}"
    end

    elapsed_ms
  end

  { arm: arm, adapter: adapter, pid: Process.pid, treatment_ms: treatment_ms, series: series }
end

def worker_main
  arm = arg("arm").to_sym
  adapter = arg("adapter").to_sym
  n = Integer(arg("n"))
  out = arg("out")

  result =
    begin
      run_worker(arm: arm, adapter: adapter, n: n)
    rescue StandardError => e
      { arm: arm, adapter: adapter, pid: Process.pid, error: "#{e.class}: #{e.message}" }
    end

  File.write(out, JSON.generate(result))
  exit(result.key?(:error) ? 1 : 0)
end

# Spawns one (round, adapter, arm) combination as a fresh subprocess and
# returns its parsed result, tagged with the round/order it came from.
def spawn_worker(round:, position:, arm:, adapter:, n:)
  out = Tempfile.new(["warmup_bench", ".json"])
  out.close
  pid = Process.spawn(
    RbConfig.ruby, SELF_PATH, "--worker",
    "--arm=#{arm}", "--adapter=#{adapter}", "--n=#{n}", "--out=#{out.path}"
  )
  _pid, status = Process.wait2(pid)
  data = JSON.parse(File.read(out.path), symbolize_names: true)
  # JSON.parse only symbolizes keys, not values - :arm/:adapter must be
  # symbols again to match the ARMS/ADAPTERS constants used as hash keys
  # below, or every lookup against them silently misses.
  data[:arm] = data[:arm]&.to_sym
  data[:adapter] = data[:adapter]&.to_sym
  data.merge(round: round, position: position, exit_status: status.exitstatus)
ensure
  out.close!
end

def median(values)
  sorted = values.sort
  mid = sorted.length / 2
  sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
end

# First-N vs steady-state split, mirroring the architect's own D4 probe
# (N=60, steady-state = last 40).
def split(series)
  first_n = series.length >= 20 ? 20 : (series.length / 2.0).ceil
  [series.first(first_n), series[first_n..]]
end

def report_run(run)
  if run[:error]
    puts format(
      "  round=%d pos=%d arm=%-6s adapter=%-8s FAILED (exit=%s): %s",
      run[:round], run[:position], run[:arm], run[:adapter], run[:exit_status], run[:error]
    )
    return
  end

  first, steady = split(run[:series])
  puts format(
    "  round=%d pos=%d arm=%-6s adapter=%-8s treatment=%7.3fms  " \
    "first-%d median/min/max=%6.3f/%6.3f/%6.3f  steady(%d) median/min/max=%6.3f/%6.3f/%6.3f",
    run[:round], run[:position], run[:arm], run[:adapter], run[:treatment_ms],
    first.length, median(first), first.min, first.max,
    steady.length, median(steady), steady.min, steady.max
  )
  puts "    series (ms): #{run[:series].map { |v| format("%.3f", v) }.join(", ")}"
end

def steady_medians_by_arm(ok_runs)
  by_arm = Hash.new { |h, k| h[k] = [] }
  ok_runs.each do |r|
    _, steady = split(r[:series])
    by_arm[r[:arm]] << { round: r[:round], position: r[:position], median: median(steady) }
  end
  by_arm
end

def print_arm_medians(steady_medians)
  ARMS.each do |arm|
    entries = steady_medians[arm]
    next if entries.empty?

    vals = entries.map { |e| e[:median] }
    puts format(
      "  arm=%-6s steady-state median across %d round(s): median=%.3f min=%.3f max=%.3f (spread=%.3f)",
      arm, vals.size, median(vals), vals.min, vals.max, vals.max - vals.min
    )
    entries.each { |e| puts format("    round=%d pos=%d -> %.3f ms", e[:round], e[:position], e[:median]) }
  end
end

# Positive delta = the arm beat the none-arm baseline from the same round. A
# delta that changes sign across rounds is the standing definition of noise
# (see spec AC5) - printed explicitly rather than only the favourable rounds.
def print_deltas(steady_medians)
  none_by_round = steady_medians[:none].to_h { |e| [e[:round], e[:median]] }

  %i[gc warmup].each do |arm|
    deltas = steady_medians[arm].filter_map do |e|
      baseline = none_by_round[e[:round]]
      { round: e[:round], position: e[:position], delta_ms: baseline - e[:median] } if baseline
    end
    next if deltas.empty?

    verdict = if deltas.size < 2
      "not computable (needs >=2 rounds, got #{deltas.size})"
    else
      signs = deltas.map { |d| d[:delta_ms] <=> 0 }.uniq
      signs.size > 1 ? "SIGN FLIPS ACROSS ROUNDS - noise" : "sign consistent"
    end
    puts "  delta none-#{arm} (positive = #{arm} faster) per round: #{verdict}"
    deltas.each { |d| puts format("    round=%d pos=%d -> %+.3f ms", d[:round], d[:position], d[:delta_ms]) }
  end
end

def summarize(adapter, runs)
  failed = runs.select { |r| r[:error] }
  puts
  puts "summary: adapter=#{adapter} (#{failed.size} disconfirming/failed run(s) of #{runs.size})"

  steady_medians = steady_medians_by_arm(runs.reject { |r| r[:error] })
  print_arm_medians(steady_medians)
  print_deltas(steady_medians)
end

def print_header(smoke, n, rounds, orders)
  puts "canary parent-warmup bench (D4: does parent GC/Process.warmup help under child-side Coverage.start?)"
  puts "ruby:      #{RUBY_DESCRIPTION}"
  puts "platform:  #{RUBY_PLATFORM}"
  puts "cores:     #{Etc.nprocessors}"
  puts "N:         #{n} rollouts/arm/round, #{rounds} round(s) (#{smoke ? "smoke" : "full"} run)"
  puts "minitest:  #{Gem.loaded_specs["minitest"].version}"
  puts "rspec-core: #{Gem.loaded_specs["rspec-core"].version}"
  puts "one iteration: fork a child, load a #{EXPECTED_PASSED}-example gem-shaped submission, " \
       "run its suite with Coverage.start in the child (today's shipped placement), return " \
       "structured results; each (round, arm) is its own process, arm applied once right after preload"
  order_labels = orders.each_with_index.map { |o, i| "round#{i + 1}=#{o.join(">")}" }
  puts "orders (arm rotation per round): #{order_labels.join("  ")}"
  puts
end

def run_adapter(adapter, orders, n)
  puts "=" * 78
  puts "adapter=#{adapter}"
  runs = orders.each_with_index.flat_map do |order, round_idx|
    order.each_with_index.map do |arm, position|
      run = spawn_worker(round: round_idx + 1, position: position, arm: arm, adapter: adapter, n: n)
      report_run(run)
      run
    end
  end
  summarize(adapter, runs)
end

def orchestrator_main
  smoke = ARGV.include?("--smoke")
  n = smoke ? 5 : 60
  rounds = smoke ? 1 : 6
  orders = ARMS.permutation.to_a.first(rounds)

  print_header(smoke, n, rounds, orders)
  ADAPTERS.each { |adapter| run_adapter(adapter, orders, n) }
end

if ARGV.include?("--worker")
  worker_main
else
  orchestrator_main
end
