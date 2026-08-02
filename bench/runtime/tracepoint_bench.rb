#!/usr/bin/env ruby
# frozen_string_literal: true

# Measures TracePoint overhead: global vs targeted (`enable(target:)`), for
# :line and :call events, against an uninstrumented baseline.
#
# One iteration of the workload = one call to `WORK.run(inner)`, which runs a
# tight numeric loop of `inner` iterations calling a helper method each time.
# The helper method's ISeq is the `target:` for the targeted variants.

require "benchmark"
require "etc"

SMOKE = ARGV.include?("--smoke")

module Work
  def self.step(a, b)
    a + b
  end

  def self.run(inner)
    total = 0
    i = 0
    while i < inner
      total = step(total, i)
      i += 1
    end
    total
  end
end

TARGET_METHOD = Work.method(:step)

def timed(label, iterations)
  fired = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield(-> { fired += 1 })
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  elapsed = t1 - t0
  { label: label, iterations: iterations, elapsed: elapsed, fired: fired }
end

def report_row(result, baseline_ns_per_op)
  ns_per_op = (result[:elapsed] / result[:iterations]) * 1e9
  ops_per_sec = result[:iterations] / result[:elapsed]
  multiplier = baseline_ns_per_op ? (ns_per_op / baseline_ns_per_op) : 1.0
  printf(
    "%-32s %14.1f ns/op %16.1f ops/sec %10.2fx   (fired=%d, asserted=%s)\n",
    result[:label], ns_per_op, ops_per_sec, multiplier, result[:fired],
    (result[:fired] > 0 || result[:label] == "baseline (no TracePoint)")
  )
  ns_per_op
end

# outer = number of WORK.run calls, inner = loop size per call
outer, inner_baseline, inner_call, inner_line = if SMOKE
  [3, 2_000, 500, 50]
else
  [20, 2_000_000, 500_000, 20_000] # global :line is ~30x, sized down accordingly
end

puts "Ruby: #{RUBY_DESCRIPTION}"
puts "Platform: #{RUBY_PLATFORM}  cores: #{Etc.nprocessors}"
puts "outer=#{outer} inner_baseline=#{inner_baseline} inner_call=#{inner_call} inner_line=#{inner_line}"
puts "One iteration = Work.run(inner), a loop calling Work.step(a,b) `inner` times."
puts

# --- baseline: no TracePoint at all ---
3.times { Work.run(inner_baseline) } # warmup, identical across all variants below
baseline = timed("baseline (no TracePoint)", outer) do |_bump|
  outer.times { Work.run(inner_baseline) }
end
raise "baseline produced no work" if baseline[:iterations].zero?
baseline_ns = report_row(baseline, nil)

# --- global :call ---
3.times { Work.run(inner_call) }
gc_fired = 0
tp_global_call = TracePoint.new(:call) { |_tp| gc_fired += 1 }
tp_global_call.enable
global_call = timed("global :call", outer) do |_bump|
  outer.times { Work.run(inner_call) }
end
tp_global_call.disable
global_call[:fired] = gc_fired
raise "global :call handler never fired" if gc_fired.zero?
report_row(global_call, baseline_ns * (inner_call.to_f / inner_baseline))

# --- targeted :call (target: the Work.step method) ---
3.times { Work.run(inner_call) }
tc_fired = 0
tp_target_call = TracePoint.new(:call) { |_tp| tc_fired += 1 }
tp_target_call.enable(target: TARGET_METHOD)
target_call = timed("targeted :call", outer) do |_bump|
  outer.times { Work.run(inner_call) }
end
tp_target_call.disable
target_call[:fired] = tc_fired
raise "targeted :call handler never fired" if tc_fired.zero?
report_row(target_call, baseline_ns * (inner_call.to_f / inner_baseline))

# --- global :line ---
3.times { Work.run(inner_line) }
gl_fired = 0
tp_global_line = TracePoint.new(:line) { |_tp| gl_fired += 1 }
tp_global_line.enable
global_line = timed("global :line", outer) do |_bump|
  outer.times { Work.run(inner_line) }
end
tp_global_line.disable
global_line[:fired] = gl_fired
raise "global :line handler never fired" if gl_fired.zero?
report_row(global_line, baseline_ns * (inner_line.to_f / inner_baseline))

# --- targeted :line (target: the Work.step method) ---
3.times { Work.run(inner_line) }
tl_fired = 0
tp_target_line = TracePoint.new(:line) { |_tp| tl_fired += 1 }
tp_target_line.enable(target: TARGET_METHOD)
target_line = timed("targeted :line", outer) do |_bump|
  outer.times { Work.run(inner_line) }
end
tp_target_line.disable
target_line[:fired] = tl_fired
raise "targeted :line handler never fired" if tl_fired.zero?
report_row(target_line, baseline_ns * (inner_line.to_f / inner_baseline))

puts
puts "== targeted vs global summary =="
call_speedup = (global_call[:elapsed] / global_call[:iterations]) / (target_call[:elapsed] / target_call[:iterations])
line_speedup = (global_line[:elapsed] / global_line[:iterations]) / (target_line[:elapsed] / target_line[:iterations])
printf("targeted :call is %.2fx faster than global :call (fired global=%d targeted=%d)\n",
       call_speedup, global_call[:fired], target_call[:fired])
printf("targeted :line is %.2fx faster than global :line (fired global=%d targeted=%d)\n",
       line_speedup, global_line[:fired], target_line[:fired])

puts
puts "== events illegal for target: (recorded, not crashed) =="
%i[class end b_call b_return raise rescue].each do |ev|
  tp = TracePoint.new(ev) {}
  begin
    tp.enable(target: TARGET_METHOD)
    tp.disable
    puts "#{ev}: accepted targeted enable"
  rescue ArgumentError => e
    puts "#{ev}: ArgumentError - #{e.message}"
  end
end
