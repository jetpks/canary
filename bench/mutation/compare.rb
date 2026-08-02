#!/usr/bin/env ruby
# frozen_string_literal: true

# Compares mutant (github.com/mbj/mutant) and mutineer (github.com/*) against
# the identical gem-shaped target under bench/mutation/target, using identical
# scope and warmup for each tool. Self-contained: pulls its own gems via
# bundler/inline so it can run with plain `ruby`, independent of the repo's
# own Gemfile.
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

mutant_result   = run_mutant(timeout_s: TIMEOUT_S, smoke: SMOKE)
mutineer_result = run_mutineer(timeout_s: TIMEOUT_S, smoke: SMOKE)

puts "=== mutant ==="
pp mutant_result
puts
puts "=== mutineer ==="
pp mutineer_result
puts

puts "=== mutant licensing determination ==="
license = mutant_license_determination
puts "Source file: #{license[:source_file]}"
puts "Required flag for OSS usage: #{license[:required_flag]}"
puts "--- verbatim Mutant::Usage::Opensource::MESSAGE ---"
puts license[:verbatim_opensource_message]
puts "----------------------------------------------------"
puts

ok = mutant_result[:ok] && mutineer_result[:ok]
puts ok ? "RESULT: both tools produced and killed mutants." : "RESULT: at least one tool FAILED (see above)."
exit(ok ? 0 : 1)
