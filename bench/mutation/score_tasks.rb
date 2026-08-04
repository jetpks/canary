#!/usr/bin/env ruby
# frozen_string_literal: true

# Mutation-scores the nine v0 task graders under tasks/*/ at authoring time --
# the practical form of Grounds G5's open question ("what does it cost to
# mutation-score a real task grader") and, indirectly, of I07 F2's "is this
# grader any good": a grader that kills a high fraction of a solution's
# mutants is discriminating along more axes than one hand-picked broken
# solution can prove.
#
# tasks/** belongs to lane `corpus`, which is editing it concurrently. This
# script only ever reads solution.rb/grader.rb/meta.yml from it -- never
# writes -- and prints the SHA-256 of every file it scores so a reader can
# tell exactly which version of each task the numbers below describe.
#
# Each task's solution.rb + grader.rb pair is copied into a throwaway
# lib/+test-or-spec/ harness (same shape as bench/mutation/target/) so mutant
# and mutineer can be pointed at it exactly as they are in compare.rb --
# neither tool changes, and nothing here is wired into lib/ or a gate.
#
# Usage:
#   ruby bench/mutation/score_tasks.rb

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"
  gem "mutant", "0.16.3"
  gem "mutant-minitest", "0.16.3"
  gem "mutant-rspec", "0.16.3"
  gem "mutineer", "0.11.4"
  gem "minitest", "~> 5.25"
  gem "rspec", "~> 3.13"
end

require "open3"
require "etc"
require "timeout"
require "digest"
require "yaml"
require "tmpdir"
require "fileutils"

ROOT       = File.expand_path("..", __dir__)
TASKS_ROOT = File.join(ROOT, "..", "tasks")
TIMEOUT_S  = 90

# Same normalization compare.rb uses: each tool at ITS OWN broadest operator
# surface, since true category parity isn't reachable through either public
# interface (see compare.rb's header for why).
MUTINEER_ALL_OPERATORS = %w[
  arithmetic comparison boolean_connector boolean_literal statement_removal
  return_nil literal_mutation condition_negation string_literal regex collection_method
].join(",")

MUTANT_YML = <<~YAML
  ---
  usage: opensource
  mutation:
    operators: full
YAML

# --- helpers (same shape as compare.rb's, duplicated rather than shared so
# this script stays independently runnable) -------------------------------

def run_with_timeout(cmd, chdir:, timeout_s:)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  stdout_str = +""
  status = nil

  Bundler.with_unbundled_env do
    Open3.popen3(*cmd, chdir: chdir) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      out_reader = Thread.new { stdout_str << stdout.read }
      err_reader = Thread.new { stdout_str << stderr.read }

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
  { stdout: stdout_str, status: status, elapsed: elapsed }
end

def tail(str, n)
  str.to_s.length > n ? str[-n..] : str.to_s
end

# Top-level class/module/constant-assigned-Class names in +path+, e.g.
# "Vector = Struct.new(...)" -> [:Vector]. Used to build mutant's subject
# expressions ("Money*") without hand-maintaining a task -> subject table --
# every v0 task defines its subject(s) as a top-level constant.
def top_level_subjects(path)
  ast = RubyVM::AbstractSyntaxTree.parse(File.read(path))
  names = []
  visit = lambda do |node|
    next unless node.is_a?(RubyVM::AbstractSyntaxTree::Node)
    case node.type
    when :CLASS, :MODULE
      names << node.children[0].children.last
    when :CASGN, :CDECL
      names << node.children[0..1].find { |c| c.is_a?(Symbol) }
    when :SCOPE, :BLOCK, :BEGIN
      node.children.each { |c| visit.call(c) }
    end
  end
  visit.call(ast.children.last)
  names.compact.uniq
end

# Builds a throwaway lib/+test-or-spec/ harness from a task's solution.rb and
# grader.rb, mirroring bench/mutation/target/'s shape. +cover_subjects+, when
# given, injects mutant-minitest's `cover` DSL into the one minitest test
# class so mutant's coverage map resolves (RSpec doesn't need this -- with no
# per-example expression metadata, mutant-rspec falls back to matching every
# example against every subject).
def build_harness(name, adapter, solution_src, grader_src, cover_subjects: nil)
  dir = Dir.mktmpdir("canary-mutation-#{name}-")
  FileUtils.mkdir_p(File.join(dir, "lib"))
  File.write(File.join(dir, "lib", "solution.rb"), solution_src)

  if adapter == :minitest
    FileUtils.mkdir_p(File.join(dir, "test"))
    body = grader_src
    if cover_subjects
      covers = cover_subjects.map { |s| "  cover #{"#{s}*".inspect}\n" }.join
      body = body.sub(/(class \w+ < Minitest::Test\n)/) { "#{Regexp.last_match(1)}#{covers}\n" }
    end
    File.write(File.join(dir, "test", "grader_test.rb"),
      %(require "minitest/autorun"\nrequire_relative "../lib/solution"\n\n) + body)
  else
    FileUtils.mkdir_p(File.join(dir, "spec"))
    File.write(File.join(dir, "spec", "grader_spec.rb"),
      %(require "rspec/expectations"\nrequire_relative "../lib/solution"\n\n) + grader_src)
  end

  File.write(File.join(dir, ".mutant.yml"), MUTANT_YML)
  dir
end

# Runs the grader against the real reference solution with plain
# minitest/rspec (no mutation tool involved) -- the success assertion that
# proves the harness itself is sound before any mutant/mutineer number is
# trusted.
def baseline_passes?(dir, adapter)
  if adapter == :minitest
    out, status = Open3.capture2e("ruby", "-Ilib", "-Itest", "test/grader_test.rb", chdir: dir)
  else
    out, status = Open3.capture2e("rspec", "-Ilib", "spec/grader_spec.rb", chdir: dir)
  end
  [status.success?, out]
end

def run_mutant(dir, adapter, subjects, timeout_s:)
  includes = ["lib"]
  requires = ["solution"]

  if adapter == :minitest
    includes << (Gem::Specification.find_by_name("mutant-minitest").gem_dir + "/lib")
    requires << "mutant/integration/minitest"
    use = "minitest"
  else
    includes << (Gem::Specification.find_by_name("mutant-rspec").gem_dir + "/lib")
    includes << (Gem::Specification.find_by_name("rspec-expectations").gem_dir + "/lib")
    requires = ["rspec/expectations"] + requires + ["mutant/integration/rspec"]
    use = "rspec"
  end

  cmd = ["mutant", "run"]
  includes.each { |i| cmd += ["--include", i] }
  requires.each { |r| cmd += ["--require", r] }
  cmd += ["--use", use, "--usage", "opensource"] + subjects.map { |s| "#{s}*" }

  result = run_with_timeout(cmd, chdir: dir, timeout_s: timeout_s)
  return { tool: "mutant", ok: false, reason: "timed out after #{timeout_s}s. cmd: #{cmd.join(' ')}" } if result[:status] == :timeout

  out = result[:stdout]
  mutations = out[/^Mutations:\s+(\d+)/, 1]&.to_i
  kills     = out[/^Kills:\s+(\d+)/, 1]&.to_i
  timeouts  = out[/^Timeouts:\s+(\d+)/, 1]&.to_i
  coverage  = out[/^Coverage:\s+([\d.]+)%/, 1]&.to_f
  subjects_found = out[/^Subjects:\s+(\d+)/, 1]&.to_i

  if mutations.nil?
    return { tool: "mutant", ok: false, reason: "could not parse output. cmd: #{cmd.join(' ')}\n--- tail ---\n#{tail(out, 1500)}" }
  end

  {
    tool: "mutant", ok: true, cmd: cmd.join(" "), subjects_found: subjects_found,
    wall_clock_s: result[:elapsed].round(3), mutants_total: mutations, mutants_killed: kills,
    mutant_timeouts: timeouts, reported_coverage_pct: coverage,
    score_pct: mutations.positive? ? (kills.to_f / mutations * 100).round(2) : nil,
    ms_per_mutant: mutations.positive? ? (result[:elapsed] * 1000 / mutations).round(3) : nil
  }
end

def run_mutineer(dir, adapter, timeout_s:)
  test_file = adapter == :minitest ? "test/grader_test.rb" : "spec/grader_spec.rb"
  cmd = ["mutineer", "run", "lib/solution.rb", "--test", test_file,
         "--operators", MUTINEER_ALL_OPERATORS, "--framework", adapter.to_s,
         "--jobs", Etc.nprocessors.to_s, "--format", "json"]

  result = run_with_timeout(cmd, chdir: dir, timeout_s: timeout_s)
  return { tool: "mutineer", ok: false, reason: "timed out after #{timeout_s}s. cmd: #{cmd.join(' ')}" } if result[:status] == :timeout

  json_text = result[:stdout][/\{.*\}/m]
  if json_text.nil?
    return { tool: "mutineer", ok: false, reason: "no JSON found. cmd: #{cmd.join(' ')}\n--- tail ---\n#{tail(result[:stdout], 1500)}" }
  end

  data    = JSON.parse(json_text)
  summary = data.fetch("summary")
  total   = summary.fetch("attempted")

  if total.zero?
    return { tool: "mutineer", ok: false, reason: "0 mutants attempted. cmd: #{cmd.join(' ')}\n#{json_text}" }
  end

  {
    tool: "mutineer", ok: true, cmd: cmd.join(" "),
    wall_clock_s: result[:elapsed].round(3), mutants_total: total, mutants_killed: summary.fetch("killed"),
    no_coverage: summary.fetch("no_coverage"), score_pct: summary.fetch("score"),
    ms_per_mutant: (result[:elapsed] * 1000 / total).round(3)
  }
end

require "json"

# --- run -------------------------------------------------------------------

puts "=== Environment ==="
puts "Ruby:      #{RUBY_DESCRIPTION}"
puts "Platform:  #{RUBY_PLATFORM}"
puts "Cores:     #{Etc.nprocessors}"
puts "mutant:      #{Bundler.with_unbundled_env { `mutant --version`.strip }}"
puts "mutineer:    #{Bundler.with_unbundled_env { `mutineer --version`.strip }}"
puts

task_dirs = Dir.children(TASKS_ROOT).sort.select { |n| File.directory?(File.join(TASKS_ROOT, n)) }
puts "=== Tasks scored (read-only; SHA-256 of each file at time of scoring) ==="
rows = task_dirs.map do |name|
  dir = File.join(TASKS_ROOT, name)
  solution_path = File.join(dir, "solution.rb")
  grader_path   = File.join(dir, "grader.rb")
  meta          = YAML.load_file(File.join(dir, "meta.yml"), symbolize_names: true)

  solution_sha = Digest::SHA256.file(solution_path).hexdigest
  grader_sha   = Digest::SHA256.file(grader_path).hexdigest
  puts format("%-28s solution.rb=%s grader.rb=%s", name, solution_sha[0, 12], grader_sha[0, 12])

  { name: name, dir: dir, adapter: meta.fetch(:adapter).to_sym, solution_path: solution_path,
    grader_path: grader_path, solution_sha: solution_sha, grader_sha: grader_sha }
end
puts

results = rows.map do |row|
  solution_src = File.read(row[:solution_path])
  grader_src   = File.read(row[:grader_path])
  subjects     = top_level_subjects(row[:solution_path])

  shared_dir = build_harness(row[:name], row[:adapter], solution_src, grader_src)
  mutant_dir = if row[:adapter] == :minitest
                 build_harness("#{row[:name]}-mutant", row[:adapter], solution_src, grader_src, cover_subjects: subjects)
               else
                 shared_dir
               end

  baseline_ok, baseline_out = baseline_passes?(shared_dir, row[:adapter])
  raise "#{row[:name]}: reference solution does not pass its own grader in the harness!\n#{baseline_out}" unless baseline_ok

  mutant_result   = run_mutant(mutant_dir, row[:adapter], subjects, timeout_s: TIMEOUT_S)
  mutineer_result = run_mutineer(shared_dir, row[:adapter], timeout_s: TIMEOUT_S)

  FileUtils.remove_entry(shared_dir)
  FileUtils.remove_entry(mutant_dir) unless mutant_dir == shared_dir

  { name: row[:name], adapter: row[:adapter], subjects: subjects, baseline_ok: baseline_ok,
    mutant: mutant_result, mutineer: mutineer_result }
end

puts "=== Per-task mutation score (baseline assertion: reference solution passes its own grader, asserted above raise-on-failure) === "
puts format("%-28s %-9s %-22s | %8s %7s %7s %10s | %8s %7s %7s %10s",
  "task", "adapter", "subjects", "mut#", "killed", "score%", "wall_s", "mut#", "killed", "score%", "wall_s")
results.each do |r|
  m  = r[:mutant]
  mi = r[:mutineer]
  m_str  = m[:ok]  ? format("%8d %7d %6.1f%% %9.3f",  m[:mutants_total],  m[:mutants_killed],  m[:score_pct]  || 0.0, m[:wall_clock_s])  : format("%8s %7s %7s %10s", "FAIL", "-", "-", "-")
  mi_str = mi[:ok] ? format("%8d %7d %6.1f%% %9.3f", mi[:mutants_total], mi[:mutants_killed], mi[:score_pct] || 0.0, mi[:wall_clock_s]) : format("%8s %7s %7s %10s", "FAIL", "-", "-", "-")
  puts format("%-28s %-9s %-22s | %s | %s", r[:name], r[:adapter], r[:subjects].join(","), m_str, mi_str)
  puts "  mutant FAIL reason: #{m[:reason]}" unless m[:ok]
  puts "  mutineer FAIL reason: #{mi[:reason]}" unless mi[:ok]
end
puts
puts "ms/mutant (mutant vs mutineer), per task:"
results.each do |r|
  m_ms  = r[:mutant][:ok]  && r[:mutant][:ms_per_mutant]  ? format("%.3f", r[:mutant][:ms_per_mutant])  : "N/A (0 mutants found)"
  mi_ms = r[:mutineer][:ok] && r[:mutineer][:ms_per_mutant] ? format("%.3f", r[:mutineer][:ms_per_mutant]) : "N/A (0 mutants found)"
  puts format("  %-28s mutant=%-10s mutineer=%-10s", r[:name], m_ms, mi_ms)
end
puts
puts "NOTE: wall_clock_s above is an UPPER BOUND -- measured with other lanes' " \
     "agents potentially running concurrently on this host (Grounds G6); it is not a " \
     "per-rollout cost and is not a clean single-tenant benchmark."
