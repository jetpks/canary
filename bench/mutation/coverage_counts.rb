#!/usr/bin/env ruby
# frozen_string_literal: true

# Answers BRIEF Sec6.4's tool-coverage question with deterministic counts: for
# each of the 15 tasks under tasks/**, how many subjects does each tool's
# STATIC discovery find, and how many mutations does it generate from them --
# before either tool runs a single test. I09 established, live, two
# asymmetric blind spots: mutant finds 0 subjects on struct_vector (a
# `Struct.new(...) do...end` body) while mutineer's Project.discover, which
# walks every Prism::DefNode regardless of enclosing scope, finds mutations
# there; and mutineer finds 0 mutations on ensure_return_swallows_exception
# (an `ensure` clause) while mutant finds 13. This script confirms or
# contradicts those pairs live and extends the same measurement to the rest
# of the corpus, including `refine` (refinement_hollow_check) and `prepend`
# (prepend_logging_wrapper), which I08/I09 did not check.
#
# Deliberately does NOT run either tool's mutation-KILLING step -- no test
# execution, no scores, no kills, no wall-clock -- only static/dry-run
# discovery, which is what Sec6.4's question is actually about (Grounds G6:
# this iteration reports no timing figure of any kind, and a discovery-only
# question does not need one). mutant's own `environment show` subcommand and
# mutineer's own `--dry-run` mode both already separate discovery from
# execution; this asks each tool that native question rather than inferring
# counts from a killed-mutant run. Confirmed live (see this script's own run)
# that both tools report the identical Subjects:/Mutations: counts with or
# without a test directory present, so the harness below carries lib/
# only -- no grader, no test framework wiring.
#
# tasks/** belongs to lane `corpus`, which is rewriting it concurrently this
# iteration; this script only ever reads solution.rb from it, never writes,
# and prints the exact commit + SHA-256 of every file it reads so a reader
# can tell exactly which version of each task these counts describe. Per
# Grounds G7, none of this is a durable per-task mutation SCORE (this script
# computes no score at all, and touches no grader.rb) -- it is a tool/shape
# fact, independent of how any given task's grader is written.
#
# Usage:
#   ruby bench/mutation/coverage_counts.rb

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
require "timeout"
require "digest"
require "yaml"
require "tmpdir"
require "fileutils"

ROOT       = File.expand_path("..", __dir__)
TASKS_ROOT = File.join(ROOT, "..", "tasks")
TIMEOUT_S  = 60

# Same normalization compare.rb / score_tasks.rb use: mutineer at its own
# broadest operator surface (tier 1 + tier 2), since true category parity
# with mutant's "full" isn't reachable through either tool's public interface
# (see compare.rb's header for why).
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

# --- helpers (same shape as score_tasks.rb's, duplicated rather than shared
# so this script stays independently runnable) -----------------------------

def run_with_timeout(cmd, chdir:, timeout_s:)
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
  { stdout: stdout_str, status: status }
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

def build_harness(name, solution_src)
  dir = Dir.mktmpdir("canary-coverage-#{name}-")
  FileUtils.mkdir_p(File.join(dir, "lib"))
  File.write(File.join(dir, "lib", "solution.rb"), solution_src)
  File.write(File.join(dir, ".mutant.yml"), MUTANT_YML)
  dir
end

# mutant's static discovery: `environment show` bootstraps the matcher and
# prints Subjects:/Mutations: without running a single mutation against a
# test -- the tool's own separation of discovery from execution.
def mutant_discovery(dir, adapter, subjects, timeout_s:)
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

  cmd = ["mutant", "environment", "show"]
  includes.each { |i| cmd += ["--include", i] }
  requires.each { |r| cmd += ["--require", r] }
  cmd += ["--use", use, "--usage", "opensource"] + subjects.map { |s| "#{s}*" }

  result = run_with_timeout(cmd, chdir: dir, timeout_s: timeout_s)
  return { tool: "mutant", ok: false, reason: "timed out after #{timeout_s}s. cmd: #{cmd.join(' ')}" } if result[:status] == :timeout

  out = result[:stdout]
  subjects_found = out[/^Subjects:\s+(\d+)/, 1]&.to_i
  mutations      = out[/^Mutations:\s+(\d+)/, 1]&.to_i

  if subjects_found.nil? || mutations.nil?
    return { tool: "mutant", ok: false,
             reason: "could not parse Subjects:/Mutations: from output. cmd: #{cmd.join(' ')}\n#{tail(out, 1500)}" }
  end

  { tool: "mutant", ok: true, cmd: cmd.join(" "), subjects_found: subjects_found, mutations_generated: mutations }
end

# mutineer's static discovery: Mutineer::Project.discover for subjects (its
# real, documented AST-walk entry point -- confirmed live by reading
# lib/mutineer/project.rb: a Prism::Visitor#visit_def_node with no
# enclosing-scope special-casing, which is exactly Grounds G5's claim that it
# "walks all DefNodes regardless of enclosing scope"), `--dry-run` for
# mutations (no --test needed, no test execution -- matching mutant's
# environment-show split between discovery and execution).
def mutineer_discovery(dir, timeout_s:)
  discover_cmd = ["ruby", "-Ilib", "-e",
    %(require "mutineer"; puts Mutineer::Project.discover(["lib/solution.rb"]).map(&:qualified_name))]
  discover_result = run_with_timeout(discover_cmd, chdir: dir, timeout_s: timeout_s)
  if discover_result[:status] == :timeout || !discover_result[:status]&.success?
    return { tool: "mutineer", ok: false,
             reason: "Project.discover failed. cmd: #{discover_cmd.join(' ')}\n#{tail(discover_result[:stdout], 1500)}" }
  end
  subject_names = discover_result[:stdout].lines.map(&:strip).reject(&:empty?)

  cmd = ["mutineer", "run", "--dry-run", "lib/solution.rb", "--operators", MUTINEER_ALL_OPERATORS]
  result = run_with_timeout(cmd, chdir: dir, timeout_s: timeout_s)
  return { tool: "mutineer", ok: false, reason: "timed out after #{timeout_s}s. cmd: #{cmd.join(' ')}" } if result[:status] == :timeout

  out = result[:stdout]
  mutations = out[/(\d+) mutations \(dry run, not executed\)/, 1]&.to_i
  if mutations.nil?
    return { tool: "mutineer", ok: false,
             reason: "could not parse dry-run mutation count. cmd: #{cmd.join(' ')}\n#{tail(out, 1500)}" }
  end

  { tool: "mutineer", ok: true, cmd: cmd.join(" "), subjects_found: subject_names.length,
    subject_names: subject_names, mutations_generated: mutations }
end

# --- run ---------------------------------------------------------------

puts "=== Environment ==="
puts "Ruby:     #{RUBY_DESCRIPTION}"
puts "Platform: #{RUBY_PLATFORM}"
puts "mutant:   #{Bundler.with_unbundled_env { `mutant --version`.strip }}"
puts "mutineer: #{Bundler.with_unbundled_env { `mutineer --version`.strip }}"
commit = Bundler.with_unbundled_env { `git -C #{ROOT} rev-parse HEAD`.strip }
puts "measured at commit: #{commit}"
puts

task_dirs = Dir.children(TASKS_ROOT).sort.select { |n| File.directory?(File.join(TASKS_ROOT, n)) }
puts "=== Tasks measured (read-only; solution.rb SHA-256 at time of measurement) ==="
rows = task_dirs.map do |name|
  dir = File.join(TASKS_ROOT, name)
  solution_path = File.join(dir, "solution.rb")
  meta = YAML.load_file(File.join(dir, "meta.yml"), symbolize_names: true)
  sha = Digest::SHA256.file(solution_path).hexdigest
  puts format("%-32s adapter=%-8s solution.rb=%s", name, meta.fetch(:adapter), sha[0, 12])
  { name: name, adapter: meta.fetch(:adapter).to_sym, solution_path: solution_path }
end
puts

results = rows.map do |row|
  solution_src = File.read(row[:solution_path])
  subjects = top_level_subjects(row[:solution_path])
  harness = build_harness(row[:name], solution_src)

  mutant_result   = mutant_discovery(harness, row[:adapter], subjects, timeout_s: TIMEOUT_S)
  mutineer_result = mutineer_discovery(harness, timeout_s: TIMEOUT_S)

  FileUtils.remove_entry(harness)

  { name: row[:name], adapter: row[:adapter], subjects: subjects, mutant: mutant_result, mutineer: mutineer_result }
end

puts "=== Per-task static discovery counts (mutant `environment show` / mutineer `--dry-run` " \
     "+ Project.discover -- no test execution, no scores, no timing) ==="
puts format("%-34s %-9s %-32s | %6s %6s | %6s %6s",
  "task", "adapter", "top-level constants", "m.sub#", "m.mut#", "mi.sub#", "mi.mut#")
results.each do |r|
  m  = r[:mutant]
  mi = r[:mutineer]
  m_str  = m[:ok]  ? format("%6d %6d", m[:subjects_found], m[:mutations_generated])  : format("%6s %6s", "FAIL", "-")
  mi_str = mi[:ok] ? format("%6d %6d", mi[:subjects_found], mi[:mutations_generated]) : format("%6s %6s", "FAIL", "-")
  puts format("%-34s %-9s %-32s | %s | %s", r[:name], r[:adapter], r[:subjects].join(","), m_str, mi_str)
  puts "  mutant FAIL: #{m[:reason]}" unless m[:ok]
  puts "  mutineer FAIL: #{mi[:reason]}" unless mi[:ok]
end
puts

puts "=== mutineer subject names discovered per task (Project.discover) ==="
results.each do |r|
  puts format("  %-34s %s", r[:name], r[:mutineer][:ok] ? r[:mutineer][:subject_names].join(", ") : "N/A")
end
puts

puts "=== I09 F4 live cross-check ==="
sv = results.find { |r| r[:name] == "struct_vector" }
ee = results.find { |r| r[:name] == "ensure_return_swallows_exception" }
puts format("struct_vector: mutant subjects=%s (I09 cited 0)  mutineer mutations=%s (I09 cited 3)",
  sv[:mutant][:ok] ? sv[:mutant][:subjects_found] : "FAIL",
  sv[:mutineer][:ok] ? sv[:mutineer][:mutations_generated] : "FAIL")
puts format("ensure_return_swallows_exception: mutineer mutations=%s (I09 cited 0)  mutant mutations=%s (I09 cited 13)",
  ee[:mutineer][:ok] ? ee[:mutineer][:mutations_generated] : "FAIL",
  ee[:mutant][:ok] ? ee[:mutant][:mutations_generated] : "FAIL")
puts

zero_subject = results.select { |r| r[:mutant][:ok] && r[:mutant][:subjects_found].zero? }
puts "=== silent-zero guard: tasks where mutant's static discovery found 0 subjects ==="
puts "(a real `mutant run` on any of these still prints \"Coverage: 100.00%\" and exits 0 -- see report)"
zero_subject.each { |r| puts "  #{r[:name]}" }
puts "count: #{zero_subject.length} of #{results.length}"
puts

failed = results.flat_map { |r| [r[:mutant], r[:mutineer]] }.reject { |t| t[:ok] }
puts "disconfirming/failed discovery runs: #{failed.length}"
failed.each { |t| puts "  #{t[:tool]}: #{t[:reason]}" }
exit(failed.empty? ? 0 : 1)
