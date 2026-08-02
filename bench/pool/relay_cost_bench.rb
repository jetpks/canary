#!/usr/bin/env ruby
# frozen_string_literal: true

# Measures the per-rollout cost of I07's trusted relay hop
# (lib/canary/pool.rb #relay) - the extra fork + inner pipe + IO.copy_stream
# that closed Sec4.5's rank-1 pipe-hijack - against BRIEF Sec3.4's cost bands
# (~+6ms accepted, +100ms vetoed). This is I07 F1.
#
# lib/ is READ-ONLY for this bench. The "before" (relay-less) arm is built at
# runtime as a scratch copy of lib/ (Dir.mktmpdir) with only the relay hop
# textually removed from a copy of pool.rb - build_relayless_lib! below - so
# the two trees differ in exactly one hop and nothing else (Sec3.4's other
# I07/I08 changes, e.g. the wire-integrity check and success?'s
# total.positive?, stay identical in both arms). No relay: flag is ever added
# to shipped code.
#
# Each (round, arm) is measured in its own fresh subprocess (mirroring
# warmup_bench.rb's spawn_worker/run_worker shape): the worker requires
# canary from whichever libdir it was told to (real or scratch), builds a
# single-adapter Pool, runs one unmeasured warmup rollout, then N measured,
# individually-timed, success-asserted rollouts, all steady-state within that
# one process. The 8 arms (2 adapters x coverage on/off x relay/no-relay) are
# order-alternated across rounds using tracepoint_bench.rb's rotate-by-one
# schedule and its printed position ledger with a raise on nonzero spread.
#
# A host-variance control (one fixed arm, repeated in independent
# subprocesses, nothing varying but real OS scheduling - same idea as
# tracepoint_bench.rb's CONTROL_REPEATS) establishes the noise floor the
# relay delta has to clear before it is reported as a real cost rather than
# noise.
#
#   bundle exec ruby bench/pool/relay_cost_bench.rb          # full run
#   bundle exec ruby bench/pool/relay_cost_bench.rb --smoke  # fast gate check

require "etc"
require "json"
require "tempfile"
require "tmpdir"
require "fileutils"
require "rbconfig"

SELF_PATH = File.expand_path(__FILE__)
REAL_LIB_DIR = File.expand_path("../../lib", __dir__)
FIXTURES = {
  minitest: File.expand_path("fixtures/minitest_submission.rb", __dir__),
  rspec: File.expand_path("fixtures/rspec_submission.rb", __dir__),
}.freeze
EXPECTED_PASSED = 21

ARMS = [
  { key: :minitest_cov_off_relay_on, adapter: :minitest, coverage: false, relay: true },
  { key: :minitest_cov_off_relay_off, adapter: :minitest, coverage: false, relay: false },
  { key: :minitest_cov_on_relay_on, adapter: :minitest, coverage: true, relay: true },
  { key: :minitest_cov_on_relay_off, adapter: :minitest, coverage: true, relay: false },
  { key: :rspec_cov_off_relay_on, adapter: :rspec, coverage: false, relay: true },
  { key: :rspec_cov_off_relay_off, adapter: :rspec, coverage: false, relay: false },
  { key: :rspec_cov_on_relay_on, adapter: :rspec, coverage: true, relay: true },
  { key: :rspec_cov_on_relay_off, adapter: :rspec, coverage: true, relay: false },
].freeze
ARM_COUNT = ARMS.length
raise "ARM_COUNT (#{ARM_COUNT}) must be 8 (2 adapters x 2 coverage x 2 relay)" unless ARM_COUNT == 8

# The fixed arm the host-variance control repeats - cheapest combination
# (no coverage), chosen only to keep the extra control spawns fast; it says
# nothing about the relay itself, since relay=true stays constant across
# every control rep.
CONTROL_ARM = ARMS.find { |a| a[:key] == :minitest_cov_off_relay_on }.freeze

def arg(name)
  match = ARGV.find { |a| a.start_with?("--#{name}=") }
  match&.split("=", 2)&.last
end

# ---------------------------------------------------------------------------
# Worker mode - runs in its own fresh subprocess, one per (round, arm).
# ---------------------------------------------------------------------------

def run_worker(adapter:, coverage:, relay:, n:)
  pool_source_location = Canary::Pool.instance_method(:rollout).source_location.join(":")
  pool = Canary::Pool.new(adapters: [adapter])
  path = FIXTURES.fetch(adapter)

  # Unmeasured, to shake out the fixture's own one-time costs (autoloaded
  # constants etc.) - same reason rollout_bench.rb / warmup_bench.rb do this
  # - so the timed series below reflects steady-state per-rollout cost.
  pool.rollout(adapter: adapter, submission_path: path, coverage: coverage)

  series = Array.new(n) do
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    result = pool.rollout(adapter: adapter, submission_path: path, coverage: coverage)
    elapsed_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000.0

    unless result.error.nil? && result.passed == EXPECTED_PASSED && result.failed.zero?
      raise "measurement invalid: adapter=#{adapter} coverage=#{coverage} relay=#{relay} " \
            "expected #{EXPECTED_PASSED} passed/0 failed, got " \
            "#{result.passed} passed/#{result.failed} failed error=#{result.error.inspect}"
    end

    elapsed_ms
  end

  {
    adapter: adapter, coverage: coverage, relay: relay, pid: Process.pid,
    pool_source_location: pool_source_location, series: series,
  }
end

def worker_main
  libdir = arg("libdir")
  adapter = arg("adapter").to_sym
  coverage = arg("coverage") == "true"
  relay = arg("relay") == "true"
  n = Integer(arg("n"))
  out = arg("out")

  # bundle exec's own gemspec evaluation already require_relative'd the real
  # lib/canary/version.rb before this script ran (canary.gemspec pulls it in
  # to read Canary::VERSION); requiring the scratch tree's copy of the same
  # file is a second, different absolute path, so Ruby (correctly) loads it
  # again rather than treating it as already-loaded, and warns about the
  # constant. Harmless - version.rb carries no relay-related code - so it's
  # silenced around just this require rather than left to clutter the report.
  original_verbose = $VERBOSE
  $VERBOSE = nil
  require File.join(libdir, "canary")
  $VERBOSE = original_verbose

  result =
    begin
      run_worker(adapter: adapter, coverage: coverage, relay: relay, n: n)
    rescue StandardError => e
      { adapter: adapter, coverage: coverage, relay: relay, pid: Process.pid, error: "#{e.class}: #{e.message}" }
    end

  File.write(out, JSON.generate(result))
  exit(result.key?(:error) ? 1 : 0)
end

# ---------------------------------------------------------------------------
# Scratch relay-less tree (Sec3.4's design decision, G3): a byte-identical
# copy of lib/, except lib/canary/pool.rb has the relay hop - the call into
# #relay, and #relay itself - textually removed. Raises if the expected
# source text has moved, so a future edit to pool.rb can't silently make
# this bench measure the wrong code instead of failing loudly.
# ---------------------------------------------------------------------------

# NOTE: these use <<-RUBY (not <<~RUBY) deliberately - a squiggly heredoc
# strips leading whitespace to the *block's own* minimum indent, which would
# silently normalize away the absolute indentation these need to match
# byte-for-byte against the real source file below.
ORIGINAL_FORK_BLOCK = <<-RUBY
      pid = fork do
        reader.close
        # Lead its own process group so a timeout can kill every descendant
        # the submission leaves behind, not just this one pid. The worker
        # #relay forks below inherits this group automatically.
        Process.setpgid(0, 0)
        writer.binmode
        relay(writer, &block)
      end
  RUBY

RELAYLESS_FORK_BLOCK = <<-RUBY
      pid = fork do
        reader.close
        # Lead its own process group so a timeout can kill every descendant
        # the submission leaves behind, not just this one pid.
        Process.setpgid(0, 0)
        writer.binmode
        Marshal.dump(block.call, writer)
        writer.close
        exit!(0)
      end
  RUBY

RELAY_METHOD = <<-RUBY
    # Runs inside the process #fork_and_collect just forked (the "relay").
    # The relay never runs a line of the submission itself: it forks a
    # second child (the "worker") to do that, and the worker closes
    # +writer+ - the parent-facing pipe it would otherwise have inherited -
    # before the submission gets to run at all. A pipe closed this way has
    # no path back open from inside the worker: not via ObjectSpace, not via
    # a guessed file descriptor, not via /dev/fd (verified against this
    # interpreter on darwin - each raises Errno::EBADF). The relay itself
    # only ever forwards bytes between two pipes it owns; it never
    # interprets or trusts them, and it reproduces the worker's own exit
    # status so the parent's failure taxonomy (crash/signal/timeout) still
    # reads off a single Process.wait2 the way it always has.
    def relay(writer, &block)
      inner_reader, inner_writer = IO.pipe
      inner_writer.binmode

      worker_pid = fork do
        inner_reader.close
        writer.close
        Marshal.dump(block.call, inner_writer)
        inner_writer.close
        exit!(0)
      end

      inner_writer.close
      IO.copy_stream(inner_reader, writer)
      inner_reader.close
      _worker_pid, worker_status = Process.wait2(worker_pid)
      writer.close

      Process.kill(worker_status.termsig, Process.pid) if worker_status.signaled?
      exit!(worker_status.exitstatus || 1)
    end

  RUBY

def build_relayless_lib!
  scratch_root = Dir.mktmpdir("relay_cost_bench")
  scratch_lib = File.join(scratch_root, "lib")
  FileUtils.cp_r(REAL_LIB_DIR, scratch_lib)

  pool_path = File.join(scratch_lib, "canary", "pool.rb")
  source = File.read(pool_path)

  unless source.include?(ORIGINAL_FORK_BLOCK)
    raise "relay_cost_bench: expected fork block text not found in #{pool_path} - " \
          "lib/canary/pool.rb has drifted from what this bench was written against"
  end
  unless source.include?(RELAY_METHOD)
    raise "relay_cost_bench: expected #relay method text not found in #{pool_path} - " \
          "lib/canary/pool.rb has drifted from what this bench was written against"
  end

  patched = source.sub(ORIGINAL_FORK_BLOCK, RELAYLESS_FORK_BLOCK).sub(RELAY_METHOD, "")
  File.write(pool_path, patched)

  [scratch_root, scratch_lib]
end

def print_tree_diff(real_pool, scratch_pool)
  puts "== diff: real lib/canary/pool.rb vs scratch relay-less lib/canary/pool.rb =="
  diff_output = IO.popen(["diff", "-u", real_pool, scratch_pool], &:read)
  puts diff_output
  if diff_output.strip.empty?
    raise "relay_cost_bench: scratch pool.rb is byte-identical to the real one - the relay removal did not apply"
  end
end

# ---------------------------------------------------------------------------
# Orchestrator mode
# ---------------------------------------------------------------------------

def loadavg
  `sysctl -n vm.loadavg`.strip
end

def process_snapshot
  `ps -eo pcpu,pid,comm | sort -rn | head -15`
end

def print_host_quiet(label)
  puts "== host-quiet check (#{label}) =="
  puts "sysctl -n vm.loadavg: #{loadavg}"
  puts "ps -eo pcpu,pid,comm | sort -rn | head -15:"
  puts process_snapshot
end

def median(values)
  sorted = values.sort
  mid = sorted.length / 2
  sorted.length.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
end

def stats(values)
  sorted = values.sort
  { min: sorted.first, median: median(values), max: sorted.last }
end

def spread(values)
  sorted = values.sort
  sorted.max - sorted.min
end

# Robust to a single scheduling outlier the way min/max range is not - see
# tracepoint_bench.rb's header comment: one bad rep among many can inflate a
# raw range enough to swallow a genuine small effect into "no measurable
# difference." Q3-Q1 ignores whatever sits in the tails.
def iqr(values)
  sorted = values.sort
  q1 = sorted[[(sorted.length * 0.25).to_i, sorted.length - 1].min]
  q3 = sorted[[(sorted.length * 0.75).to_i, sorted.length - 1].min]
  q3 - q1
end

def spawn_worker(round:, position:, arm:, libdir:, n:)
  out = Tempfile.new(["relay_cost_bench", ".json"])
  out.close
  pid = Process.spawn(
    RbConfig.ruby, SELF_PATH, "--worker",
    "--libdir=#{libdir}", "--adapter=#{arm[:adapter]}", "--coverage=#{arm[:coverage]}",
    "--relay=#{arm[:relay]}", "--n=#{n}", "--out=#{out.path}"
  )
  _pid, status = Process.wait2(pid)
  data = JSON.parse(File.read(out.path), symbolize_names: true)
  data[:adapter] = data[:adapter]&.to_sym
  data.merge(round: round, position: position, arm_key: arm[:key], exit_status: status.exitstatus)
ensure
  out.close!
end

def report_run(run)
  if run[:error]
    puts format("  round=%d pos=%d arm=%-28s FAILED (exit=%s): %s",
      run[:round], run[:position], run[:arm_key], run[:exit_status], run[:error])
    return
  end

  s = stats(run[:series])
  puts format("  round=%d pos=%d arm=%-28s median/min/max=%7.3f/%7.3f/%7.3f ms  n=%d  src=%s",
    run[:round], run[:position], run[:arm_key], s[:median], s[:min], s[:max], run[:series].length,
    run[:pool_source_location])
end

def print_position_ledger(runs, rounds)
  puts "== position ledger (0 = measured first/coldest that round, #{ARM_COUNT - 1} = measured last/warmest) =="
  ok_runs = runs.reject { |r| r[:error] }
  by_arm = ok_runs.group_by { |r| r[:arm_key] }
  mean_positions = {}
  ARMS.each do |arm|
    positions = (by_arm[arm[:key]] || []).map { |e| e[:position] }
    mean = positions.empty? ? Float::NAN : positions.sum.to_f / positions.length
    mean_positions[arm[:key]] = mean
    puts format("%-28s positions=%-70s mean=%.3f", arm[:key], positions.inspect, mean)
  end
  finite = mean_positions.values.reject(&:nan?)
  spread_val = finite.empty? ? Float::NAN : finite.max - finite.min
  puts format("Mean-position spread across arms: %.6f slots (0.0 = perfectly balanced, ROUNDS=%d over ARM_COUNT=%d)",
    spread_val, rounds, ARM_COUNT)
  raise "relay_cost_bench: rotation is not balanced: spread=#{spread_val}" unless spread_val.abs < 1e-9
end

def print_arm_stats(runs)
  puts "== per-arm stats (absolute ms/rollout, all samples across all rounds pooled) =="
  ok_runs = runs.reject { |r| r[:error] }
  ARMS.each do |arm|
    samples = ok_runs.select { |r| r[:arm_key] == arm[:key] }.flat_map { |r| r[:series] }
    next if samples.empty?

    s = stats(samples)
    puts format(
      "  arm=%-28s adapter=%-8s coverage=%-5s relay=%-5s N=%-4d min=%7.3f median=%7.3f max=%7.3f ms  spread=%.3f",
      arm[:key], arm[:adapter], arm[:coverage], arm[:relay], samples.length, s[:min], s[:median], s[:max],
      spread(samples)
    )
  end

  failed = runs.select { |r| r[:error] }
  puts "disconfirming/failed runs: #{failed.size} of #{runs.size}"
  failed.each { |r| puts "  round=#{r[:round]} pos=#{r[:position]} arm=#{r[:arm_key]}: #{r[:error]}" }
end

def print_control(control_runs)
  puts "== host run-to-run variance control (#{control_runs.length} independent subprocesses, fixed " \
       "arm=#{CONTROL_ARM[:key]}, nothing varying but real OS scheduling) =="
  ok = control_runs.reject { |r| r[:error] }
  failed = control_runs.select { |r| r[:error] }
  medians = ok.map { |r| median(r[:series]) }
  s = stats(medians)
  spread_ms = spread(medians)
  iqr_ms = iqr(medians)
  puts format("per-subprocess medians: N=%d min=%.3f median=%.3f max=%.3f ms  raw spread=%.3f ms (%.1f%% of median)",
    medians.length, s[:min], s[:median], s[:max], spread_ms, (spread_ms / s[:median]) * 100.0)
  puts format("IQR (Q3-Q1, robust to a single scheduling outlier): %.3f ms - this is the noise floor the " \
              "ruling below compares deltas against, not the raw (outlier-sensitive) spread above", iqr_ms)
  puts "  values: #{medians.map { |v| format("%.3f", v) }.join(", ")}"
  puts "disconfirming/failed control runs: #{failed.length} of #{control_runs.size}"
  failed.each { |r| puts "  #{r[:error]}" }
  { min: s[:min], median: s[:median], max: s[:max], spread_ms: spread_ms, iqr_ms: iqr_ms }
end

def print_source_location_proof(runs)
  puts "== proof: Canary::Pool#rollout source_location per tree (AC1) =="
  ok = runs.reject { |r| r[:error] }
  relay_example = ok.find { |r| r[:relay] }
  no_relay_example = ok.find { |r| !r[:relay] }
  puts "relay=true  (real lib/):     #{relay_example && relay_example[:pool_source_location]}"
  puts "relay=false (scratch lib/):  #{no_relay_example && no_relay_example[:pool_source_location]}"
end

def print_cross_check(runs)
  puts "== cross-check vs I06's ~48-49ms covered-minitest figure (G6) =="
  ok = runs.reject { |r| r[:error] }
  before_minitest_cov = ok.select { |r| r[:arm_key] == :minitest_cov_on_relay_off }.flat_map { |r| r[:series] }
  if before_minitest_cov.empty?
    puts "NO SAMPLES for minitest/coverage=true/relay=false - cannot cross-check"
    return
  end

  s = stats(before_minitest_cov)
  cited_mid = 48.5
  pct_diff = ((s[:median] - cited_mid) / cited_mid) * 100.0
  puts format("no-relay minitest+coverage arm (the 'before' I06 measured): N=%d min=%.3f median=%.3f max=%.3f ms",
    before_minitest_cov.length, s[:min], s[:median], s[:max])
  puts "I06 cited ~48-49ms for identical (pre-relay) code."
  puts format("delta from cited midpoint (48.5ms): %+.3f ms (%+.1f%%)", s[:median] - cited_mid, pct_diff)
  verdict = if pct_diff.abs <= 10
    "reproduces (within ~10% of I06's cited figure)"
  elsif pct_diff >= 20
    "DOES NOT reproduce - INFLATED >20% above I06's cited figure - this is the same direction as I07 F1's " \
    "contamination tell (contention can only add cost, never remove it); series is suspect, do not trust the delta"
  elsif pct_diff <= -20
    "DOES NOT reproduce - LOWER than I06's cited figure by >20%. This is the OPPOSITE direction from I07 F1's " \
    "contamination (host contention can only inflate elapsed time, never deflate it below a clean baseline), " \
    "so a low reading is not evidence of the same failure mode. See the host-quiet readings and the noise-floor " \
    "control above for this run's own contamination evidence (or lack of it) instead."
  else
    "borderline (10-20% off) - reported raw, no strong claim either way"
  end
  puts "verdict: #{verdict}"
end

def print_ruling(runs, control_stats)
  puts "== Sec3.4 ruling: relay hop per-rollout cost, by adapter x coverage =="
  ok = runs.reject { |r| r[:error] }
  noise_floor_ms = control_stats[:iqr_ms]
  puts format("noise floor (host-variance control IQR, robust to a single scheduling outlier - raw spread " \
              "was %.3f ms): %.3f ms - a delta at or below this is not distinguishable from host noise on " \
              "this run", control_stats[:spread_ms], noise_floor_ms)
  puts

  %i[minitest rspec].each do |adapter|
    [false, true].each do |coverage|
      relay_arm = ARMS.find { |a| a[:adapter] == adapter && a[:coverage] == coverage && a[:relay] }
      no_relay_arm = ARMS.find { |a| a[:adapter] == adapter && a[:coverage] == coverage && !a[:relay] }
      relay_samples = ok.select { |r| r[:arm_key] == relay_arm[:key] }.flat_map { |r| r[:series] }
      no_relay_samples = ok.select { |r| r[:arm_key] == no_relay_arm[:key] }.flat_map { |r| r[:series] }

      if relay_samples.empty? || no_relay_samples.empty?
        puts format("adapter=%-8s coverage=%-5s: MISSING SAMPLES (relay N=%d, no-relay N=%d) - no ruling",
          adapter, coverage, relay_samples.length, no_relay_samples.length)
        next
      end

      relay_stats = stats(relay_samples)
      no_relay_stats = stats(no_relay_samples)
      delta = relay_stats[:median] - no_relay_stats[:median]

      verdict = if delta.abs <= noise_floor_ms
        "below noise floor - relay cost indistinguishable from host noise on this run"
      elsif delta <= 6
        "within Sec3.4 accepted band (~+6ms)"
      elsif delta >= 100
        "in Sec3.4 vetoed band (+100ms)"
      else
        "between accepted and vetoed bands - human judgement call"
      end

      puts format(
        "adapter=%-8s coverage=%-5s: relay=%7.3f ms (N=%d)  no-relay=%7.3f ms (N=%d)  delta=%+.3f ms -> %s",
        adapter, coverage, relay_stats[:median], relay_samples.length,
        no_relay_stats[:median], no_relay_samples.length, delta, verdict
      )
    end
  end
end

def orchestrator_main
  smoke = ARGV.include?("--smoke")
  n = smoke ? 2 : 8
  rounds = ARM_COUNT * (smoke ? 1 : 2)
  control_repeats = smoke ? ARM_COUNT : 20

  puts "canary relay-cost bench (I07 F1 / BRIEF Sec3.4: per-rollout cost of the trusted relay hop)"
  puts "ruby:      #{RUBY_DESCRIPTION}"
  puts "platform:  #{RUBY_PLATFORM}"
  puts "cores:     #{Etc.nprocessors}"
  puts "N:         #{n} rollouts/arm/round, #{rounds} round(s) (#{smoke ? "smoke" : "full"} run), " \
       "control_repeats=#{control_repeats}"
  puts "one iteration: fork a child (relay or direct, per arm), load a #{EXPECTED_PASSED}-example " \
       "gem-shaped submission, run its suite through the adapter, return structured results " \
       "(+coverage, when enabled); each (round, arm) is its own subprocess"
  puts

  print_host_quiet("before")
  puts

  scratch_root, scratch_lib = build_relayless_lib!
  begin
    real_pool = File.join(REAL_LIB_DIR, "canary", "pool.rb")
    scratch_pool = File.join(scratch_lib, "canary", "pool.rb")
    print_tree_diff(real_pool, scratch_pool)
    puts

    order_labels = rounds.times.map { |r| "round#{r + 1}=#{ARMS.rotate(r).map { |a| a[:key] }.join(">")}" }
    puts "arm order per round (rotated by one position per round): #{order_labels.join("  ")}"
    puts

    runs = []
    rounds.times do |r|
      ARMS.rotate(r).each_with_index do |arm, position|
        libdir = arm[:relay] ? REAL_LIB_DIR : scratch_lib
        run = spawn_worker(round: r + 1, position: position, arm: arm, libdir: libdir, n: n)
        report_run(run)
        runs << run
      end
    end
    puts

    print_position_ledger(runs, rounds)
    puts

    print_arm_stats(runs)
    puts

    control_runs = control_repeats.times.map do |i|
      spawn_worker(round: 0, position: i, arm: CONTROL_ARM, libdir: REAL_LIB_DIR, n: n)
    end
    control_stats = print_control(control_runs)
    puts

    print_source_location_proof(runs)
    puts

    print_cross_check(runs)
    puts

    print_ruling(runs, control_stats)
    puts

    print_host_quiet("after")

    failed_count = runs.count { |r| r[:error] } + control_runs.count { |r| r[:error] }
    raise "relay_cost_bench: #{failed_count} run(s) failed their success assertion - see FAILED lines above" if failed_count.positive?
  ensure
    FileUtils.remove_entry(scratch_root)
  end
end

if ARGV.include?("--worker")
  worker_main
else
  orchestrator_main
end
