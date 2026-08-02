#!/usr/bin/env ruby
# frozen_string_literal: true

# Measures Coverage overhead per mode (:lines, :branches, :methods,
# :oneshot_lines) against an uninstrumented baseline, plus the :methods
# result-time (ObjectSpace-walk) cost as live-object count grows.
#
# One iteration of the "load" benchmark = `load` a target script (fresh top
# level each time, so lines actually execute) that defines a handful of
# methods, branches, and calls them.

require "coverage"
require "benchmark"
require "etc"
require "tmpdir"
require "objspace"

SMOKE = ARGV.include?("--smoke")

TARGET_SRC = <<~RUBY
  def cov_add(a, b)
    if a > 0
      a + b
    else
      a - b
    end
  end

  def cov_mul(a, b)
    a * b
  end

  10.times do |i|
    cov_add(i, i)
    cov_add(-i, i)
    cov_mul(i, 2)
  end
RUBY

Dir.mktmpdir("coverage_bench") do |dir|
  target_path = File.join(dir, "target.rb")
  File.write(target_path, TARGET_SRC)

  load_count = SMOKE ? 20 : 5_000

  puts "Ruby: #{RUBY_DESCRIPTION}"
  puts "Platform: #{RUBY_PLATFORM}  cores: #{Etc.nprocessors}"
  puts "target file: #{target_path} (#{TARGET_SRC.lines.size} lines)"
  puts "One iteration = `load target_path` (fresh top-level eval each time)."
  puts "load_count=#{load_count}"
  puts

  def run_loads(path, count)
    count.times { load(path, true) }
  end

  def timed_mode(label, count)
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    elapsed = t1 - t0
    ns_per_op = (elapsed / count) * 1e9
    ops_per_sec = count / elapsed
    { label: label, elapsed: elapsed, ns_per_op: ns_per_op, ops_per_sec: ops_per_sec }
  end

  def report_row(row, baseline_ns, assertion)
    multiplier = baseline_ns ? row[:ns_per_op] / baseline_ns : 1.0
    printf(
      "%-24s %14.1f ns/op %16.1f ops/sec %10.2fx   (%s)\n",
      row[:label], row[:ns_per_op], row[:ops_per_sec], multiplier, assertion
    )
  end

  # --- baseline: plain `load`, no Coverage running ---
  run_loads(target_path, 5) # warmup, identical for every variant below
  baseline = timed_mode("baseline (no Coverage)", load_count) { run_loads(target_path, load_count) }
  baseline_ns = baseline[:ns_per_op]
  report_row(baseline, nil, "no Coverage running")

  modes = {
    "lines" => { lines: true },
    "branches" => { branches: true },
    "methods" => { methods: true },
    "oneshot_lines" => { oneshot_lines: true },
  }

  results = {}

  modes.each do |name, opts|
    run_loads(target_path, 5) # warmup, identical across variants (incl. baseline)
    Coverage.setup(**opts)
    Coverage.resume
    row = timed_mode(":#{name}", load_count) { run_loads(target_path, load_count) }
    result = Coverage.result # also stops coverage
    data = result[target_path]
    case name
    when "lines"
      nonzero = data[:lines].compact.count { |c| c > 0 }
      assertion = "Coverage.result[:lines] had #{data[:lines].compact.size} executable lines, #{nonzero} with count>0, asserted"
      raise "lines mode produced no executable lines" if data[:lines].compact.empty?
    when "branches"
      branch_count = data[:branches].values.sum(&:size)
      assertion = "Coverage.result[:branches] had #{data[:branches].size} branch groups / #{branch_count} branches, asserted"
      raise "branches mode produced no branch data" if data[:branches].empty?
    when "methods"
      method_count = result.values.sum { |h| h[:methods]&.size || 0 }
      assertion = "Coverage.result[:methods] had #{method_count} tracked method entries across loaded files, asserted"
      raise "methods mode produced no method data" if method_count.zero?
    when "oneshot_lines"
      hit_lines = data[:oneshot_lines].size
      assertion = "Coverage.result[:oneshot_lines] had #{hit_lines} distinct hit lines, asserted"
      raise "oneshot_lines mode produced no hit lines" if hit_lines.zero?
    end
    report_row(row, baseline_ns, assertion)
    results[name] = row
  end

  puts
  puts "== :methods result-time cost vs live-object count =="
  puts "One iteration here = a single Coverage.peek_result call (ObjectSpace walk),"
  puts "timed alone, with N live objects held in `hold` beforehand."
  puts

  Coverage.setup(methods: true)
  Coverage.resume
  load(target_path, true) # register some methods to walk

  object_counts = SMOKE ? [0, 1_000] : [0, 10_000, 100_000, 500_000, 1_000_000]
  hold = []

  printf("%14s %18s %16s %16s\n", "target_N", "ObjectSpace_count", "ns/call", "assertion")
  object_counts.each do |n|
    hold.concat(Array.new(n - hold.size) { Object.new }) if n > hold.size
    GC.start
    actual_count = ObjectSpace.count_objects[:TOTAL]

    reps = SMOKE ? 3 : 20
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    reps.times { Coverage.peek_result }
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    ns_per_call = ((t1 - t0) / reps) * 1e9

    peek = Coverage.peek_result
    method_count = peek.values.sum { |h| h[:methods]&.size || 0 }
    raise "peek_result returned no method data at N=#{n}" if method_count.zero?

    printf("%14d %18d %16.1f   peek_result had %d method entries, asserted\n",
           n, actual_count, ns_per_call, method_count)
  end
  Coverage.result # stop and clear

  puts
  puts "== oneshot vs lines exclusivity (verified) =="
  begin
    Coverage.setup(lines: true, oneshot_lines: true)
    puts "UNEXPECTED: setup(lines: true, oneshot_lines: true) did not raise"
  rescue RuntimeError => e
    puts "confirmed mutually exclusive: #{e.class} - #{e.message}"
  end
end
