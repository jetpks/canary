#!/usr/bin/env ruby
# frozen_string_literal: true

# Compares mutant (github.com/mbj/mutant) and mutineer (github.com/*) against
# the identical gem-shaped target under bench/mutation/target, using identical
# scope and warmup for each tool. Self-contained: pulls its own gems via
# bundler/inline so it can run with plain `ruby`, independent of the repo's
# own Gemfile.
#
# I08 D5: this used to run mutant, then always mutineer, every invocation -
# so any systematic effect of run position (warm disk cache, warm CPU ramp,
# see tracepoint_bench.rb's header) could only ever land on the same tool,
# which makes any ms/mutant delta between them uncitable under the standing
# order-alternation rule (Grounds G6) regardless of which tool "won". Fixed
# the same way tracepoint_bench.rb and relay_cost_bench.rb both fix it: every
# arm runs once per round, in an order rotated by one position per round,
# across a whole number of ARM_COUNT-sized periods, with a printed position
# ledger and a raise on nonzero mean-position spread proving the balance
# rather than asserting it. This makes a future rate measurement valid; it
# does not itself take or report one (see the run section below).
#
# Usage:
#   ruby bench/mutation/compare.rb           # full run against the whole target
#   ruby bench/mutation/compare.rb --smoke   # tiny scope, completes in seconds

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "mutant", "0.16.3"
  gem "mutant-minitest", "0.16.3"
  gem "mutineer", "0.11.4"
  gem "minitest", "~> 5.25"
end

require "open3"
require "json"
require "etc"
require "timeout"

SMOKE      = ARGV.include?("--smoke")
ROOT       = __dir__
TARGET_DIR = File.join(ROOT, "target")
TIMEOUT_S  = SMOKE ? 60 : 300

# Every mutineer operator, tier 1 + tier 2 (see `mutineer --list-operators`).
# Matched against mutant's "full" operator profile below: mutant has no CLI/
# config knob that selects mutation categories directly (its config.rb only
# exposes a light/full toggle on the method-selector-replacement dictionary;
# the structural mutators - literals, control flow, statement removal - are
# always on). So true category-for-category parity isn't achievable through
# either tool's public surface. The defensible normalization is: run each
# tool at ITS OWN broadest available operator surface, not its default, so
# neither count is suppressed by an asymmetric default (mutant's default is
# "light"; mutineer's is "tier 1 only").
MUTINEER_ALL_OPERATORS = %w[
  arithmetic comparison boolean_connector boolean_literal statement_removal
  return_nil literal_mutation condition_negation string_literal regex collection_method
].join(",")

# --- helpers ---------------------------------------------------------------

# bundler/inline's gemfile(true) leaves BUNDLE_GEMFILE="" and a RUBYOPT
# -rbundler/setup in ENV. Subprocesses inherit both; with an empty
# BUNDLE_GEMFILE, the child's bundler/setup walks up from its cwd looking for
# a Gemfile and finds the repo root's, then refuses to run gems (mutant,
# mutineer) that aren't in that Gemfile. Bundler.with_unbundled_env restores
# the pre-Bundler environment for the duration of the block.
def run_with_timeout(cmd, chdir:, timeout_s:)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  stdout_str = +""
  stderr_str = +""
  status = nil

  Bundler.with_unbundled_env do
    Open3.popen3(*cmd, chdir: chdir) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      out_reader = Thread.new { stdout_str << stdout.read }
      err_reader = Thread.new { stderr_str << stderr.read }

      begin
        Timeout.timeout(timeout_s) { wait_thr.join }
        status = wait_thr.value
      rescue Timeout::Error
        Process.kill("KILL", wait_thr.pid) rescue nil
        wait_thr.join
        status = :timeout
      end

      out_reader.join
      err_reader.join
    end
  end

  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  { stdout: stdout_str, stderr: stderr_str, status: status, elapsed: elapsed }
end

# String#[] with a negative start returns nil (not a clamp) when the offset
# is out of range for a short string - e.g. "ab"[-2000..] => nil. That bug
# previously discarded short error output entirely. This returns the last
# `n` characters of `str`, or all of `str` if it's shorter than that.
def tail(str, n)
  str.to_s.length > n ? str[-n..] : str.to_s
end

def fail_loudly(tool, reason)
  warn "FAILURE [#{tool}]: #{reason}"
  { tool: tool, ok: false, reason: reason }
end

def tool_version(cmd)
  result = run_with_timeout(cmd, chdir: TARGET_DIR, timeout_s: 30)
  line = result[:stdout].lines.map(&:strip).reject(&:empty?).last ||
    result[:stderr].lines.map(&:strip).reject(&:empty?).last
  line || "unknown (no output; stderr tail: #{tail(result[:stderr], 300)})"
end

# --- mutant ------------------------------------------------------------

def run_mutant(timeout_s:, smoke:)
  mutant_minitest_lib = Gem::Specification.find_by_name("mutant-minitest").gem_dir + "/lib"
  subject = smoke ? "Target::Calculator#add" : "Target*"

  cmd = [
    "mutant", "run",
    "--include", "lib",
    "--include", mutant_minitest_lib,
    "--require", "target",
    "--require", "mutant/integration/minitest",
    "--use", "minitest",
    "--usage", "opensource",
    "-j", Etc.nprocessors.to_s,
    subject
  ]

  result = run_with_timeout(cmd, chdir: TARGET_DIR, timeout_s: timeout_s)
  return fail_loudly("mutant", "timed out after #{timeout_s}s. cmd: #{cmd.join(' ')}") if result[:status] == :timeout

  out = result[:stdout]

  mutations = out[/^Mutations:\s+(\d+)/, 1]&.to_i
  kills     = out[/^Kills:\s+(\d+)/, 1]&.to_i
  coverage  = out[/^Coverage:\s+([\d.]+)%/, 1]&.to_f

  if mutations.nil? || kills.nil? || mutations.zero?
    return fail_loudly(
      "mutant",
      "could not parse a nonzero mutation count from output. " \
      "cmd: #{cmd.join(' ')}\n--- stdout tail ---\n#{tail(out, 2000)}\n--- stderr tail ---\n#{tail(result[:stderr], 1000)}"
    )
  end

  ms_per_mutant = (result[:elapsed] * 1000 / mutations).round(3)

  {
    tool:             "mutant",
    ok:               true,
    version:          tool_version(%w[mutant --version]),
    operators:        "full",
    cmd:              cmd.join(" "),
    wall_clock_s:     result[:elapsed].round(3),
    mutants_total:    mutations,
    mutants_killed:   kills,
    reported_coverage_pct: coverage,
    score_pct:        mutations.positive? ? (kills.to_f / mutations * 100).round(2) : 0.0,
    "ms/mutant":      ms_per_mutant,
    jobs:             Etc.nprocessors,
    exit_status:      result[:status].respond_to?(:exitstatus) ? result[:status].exitstatus : result[:status].to_s
  }
end

# --- mutineer ------------------------------------------------------------

def run_mutineer(timeout_s:, smoke:)
  cmd = [
    "mutineer", "run", "lib/target.rb",
    "--test", "test/target_test.rb",
    "--operators", MUTINEER_ALL_OPERATORS,
    "--jobs", Etc.nprocessors.to_s,
    "--format", "json"
  ]
  cmd += ["--only", "Target::Calculator#add"] if smoke

  result = run_with_timeout(cmd, chdir: TARGET_DIR, timeout_s: timeout_s)
  return fail_loudly("mutineer", "timed out after #{timeout_s}s. cmd: #{cmd.join(' ')}") if result[:status] == :timeout

  json_text = result[:stdout][/\{.*\}/m]
  if json_text.nil?
    return fail_loudly(
      "mutineer",
      "no JSON found in stdout. cmd: #{cmd.join(' ')}\n--- stdout tail ---\n#{tail(result[:stdout], 2000)}\n--- stderr tail ---\n#{tail(result[:stderr], 1000)}"
    )
  end

  data    = JSON.parse(json_text)
  summary = data.fetch("summary")
  total   = summary.fetch("attempted")
  killed  = summary.fetch("killed")

  if total.zero?
    return fail_loudly("mutineer", "0 mutants attempted. cmd: #{cmd.join(' ')}\n#{json_text}")
  end

  ms_per_mutant = (result[:elapsed] * 1000 / total).round(3)

  {
    tool:           "mutineer",
    ok:             true,
    version:        tool_version(%w[mutineer --version]),
    operators:      MUTINEER_ALL_OPERATORS,
    cmd:            cmd.join(" "),
    wall_clock_s:   result[:elapsed].round(3),
    mutants_total:  total,
    mutants_killed: killed,
    score_pct:      summary.fetch("score"),
    "ms/mutant":    ms_per_mutant,
    jobs:           Etc.nprocessors,
    exit_status:    result[:status].respond_to?(:exitstatus) ? result[:status].exitstatus : result[:status].to_s
  }
end

# --- licensing determination for mutant ------------------------------------

def mutant_license_determination
  usage_rb = Gem::Specification.find_by_name("mutant").gem_dir + "/lib/mutant/usage.rb"
  src   = File.read(usage_rb)
  block = src[src.index("class Opensource")...src.index("class Unknown")].lines

  message_lines = block
    .drop_while { |l| !l.include?("MESSAGE = <<~") }[1..]
    .take_while { |l| l.strip != "MESSAGE" }
    .map { |l| l.sub(/^ {8}/, "") }

  {
    source_file: usage_rb,
    required_flag: "--usage opensource",
    verbatim_opensource_message: message_lines.join
  }
end

# --- run ---------------------------------------------------------------

puts "=== Environment ==="
puts "Ruby:      #{RUBY_DESCRIPTION}"
puts "Platform:  #{RUBY_PLATFORM}"
puts "Cores:     #{Etc.nprocessors}"
puts "Mode:      #{SMOKE ? 'smoke' : 'full'}"
puts

target_lib_loc  = File.readlines(File.join(TARGET_DIR, "lib", "target.rb")).size
target_test_loc = File.readlines(File.join(TARGET_DIR, "test", "target_test.rb")).size
test_count      = File.read(File.join(TARGET_DIR, "test", "target_test.rb")).scan(/def test_/).size

puts "=== Target ==="
puts "lib files:  1 (bench/mutation/target/lib/target.rb, #{target_lib_loc} lines)"
puts "test files: 1 (bench/mutation/target/test/target_test.rb, #{target_test_loc} lines)"
puts "tests:      #{test_count}"
puts

# identical warmup: run each test suite once, untimed, before either tool,
# so neither tool pays a first-load cost the other doesn't.
Dir.chdir(TARGET_DIR) do
  system("ruby", "-Ilib", "-Itest", "test/target_test.rb", out: File::NULL, err: File::NULL)
end

# --- arm rotation (I08 D5) --------------------------------------------------
ARMS = [
  { key: :mutant,   run: ->(timeout_s, smoke) { run_mutant(timeout_s: timeout_s, smoke: smoke) } },
  { key: :mutineer, run: ->(timeout_s, smoke) { run_mutineer(timeout_s: timeout_s, smoke: smoke) } },
].freeze
ARM_COUNT = ARMS.length

# One full period (ARM_COUNT rounds) puts every arm at every rotation offset
# exactly once, so its mean measurement position is identical across arms;
# two periods in the full run for a bit more depth, one for smoke since it
# only needs to prove the schedule and the assertions still fire (same
# reasoning as tracepoint_bench.rb's REPEATS).
ROUNDS = ARM_COUNT * (SMOKE ? 1 : 2)

results_by_key = ARMS.each_with_object({}) { |a, h| h[a[:key]] = [] }
position_log   = ARMS.each_with_object({}) { |a, h| h[a[:key]] = [] }

order_labels = ROUNDS.times.map { |r| "round#{r + 1}=#{ARMS.rotate(r).map { |a| a[:key] }.join(">")}" }
puts "=== Arm order per round (rotated by one position per round) ==="
puts order_labels.join("  ")
puts

ROUNDS.times do |r|
  ARMS.rotate(r).each_with_index do |arm, position|
    result = arm[:run].call(TIMEOUT_S, SMOKE)
    results_by_key[arm[:key]] << result
    position_log[arm[:key]] << position
    puts "=== round #{r + 1}, position #{position}: #{arm[:key]} ==="
    pp result
    puts
  end
end

# The deterministic proof of balance (Grounds G6): exactly where every arm
# landed in its round, independent of any timing, checkable by reading this
# table.
puts "== position ledger (0 = measured first/coldest that round, #{ARM_COUNT - 1} = measured last/warmest) =="
mean_positions = ARMS.each_with_object({}) do |arm, h|
  positions = position_log[arm[:key]]
  mean = positions.sum.to_f / positions.length
  h[arm[:key]] = mean
  puts format("%-10s positions=%-30s mean=%.3f", arm[:key], positions.inspect, mean)
end
spread = mean_positions.values.max - mean_positions.values.min
puts format("Mean-position spread across arms: %.6f slots (0.0 = perfectly balanced, ROUNDS=%d over ARM_COUNT=%d)",
  spread, ROUNDS, ARM_COUNT)
raise "compare.rb: rotation is not balanced: spread=#{spread} (ROUNDS=#{ROUNDS} must be a multiple of ARM_COUNT=#{ARM_COUNT})" unless spread.abs < 1e-9
puts

puts "=== mutant licensing determination ==="
license = mutant_license_determination
puts "Source file: #{license[:source_file]}"
puts "Required flag for OSS usage: #{license[:required_flag]}"
puts "--- verbatim Mutant::Usage::Opensource::MESSAGE ---"
puts license[:verbatim_opensource_message]
puts "----------------------------------------------------"
puts

ok = results_by_key.values.flatten.all? { |r| r[:ok] }
puts ok ? "RESULT: both tools produced and killed mutants on every round." : "RESULT: at least one tool FAILED on at least one round (see above)."
exit(ok ? 0 : 1)
