#!/usr/bin/env ruby
# frozen_string_literal: true

# Measures TracePoint overhead: global vs targeted (`enable(target:)`), for
# :line and :call events, against an uninstrumented baseline.
#
# Every row's "unit of work" is one call to `Work.step(a, b)` (the innermost,
# traced operation), NOT one call to `Work.run`. ns/op is elapsed time divided
# by (outer * inner) -- the total number of Work.step calls -- so rows with
# different `inner` counts remain directly comparable: they're all reporting
# the cost of the same unit, just accumulated over a different number of
# repetitions to keep expensive variants (global :line) within a sane runtime.
#
# The `untargeted` variants are the deliverable: a TracePoint targeted at a
# COLD method (never called by the hot loop) while the hot, UNTARGETED loop
# runs at full size. This measures dispatch cost on non-target code paths,
# which `enable(target:)` is specifically designed to avoid -- as opposed to
# the `targeted` variants below, which target Work.step itself (the hot
# loop's entire body), so every call is a hit and they measure handler
# invocation cost, not dispatch cost. Both numbers are kept because they
# answer different questions.

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

  # Never called by Work.run -- this is the "cold" target for the
  # `untargeted` variants: a TracePoint attached here should be near-free
  # while the hot loop above (which never touches this method) runs.
  def self.cold_method(a, b)
    a - b
  end
end

TARGET_METHOD = Work.method(:step)
COLD_TARGET_METHOD = Work.method(:cold_method)

def timed(label, outer)
  fired = 0
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  yield(-> { fired += 1 })
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  { label: label, outer: outer, elapsed: t1 - t0, fired: fired }
end

# unit_count = total number of Work.step calls performed (outer * inner).
# ns/op and ops/sec are per Work.step call, so every row -- regardless of its
# `inner` -- reports the cost of the same unit of work.
def report_row(result, unit_count, baseline_ns_per_op, expected_fired_zero: false, no_tracepoint: false)
  ns_per_op = (result[:elapsed] / unit_count) * 1e9
  ops_per_sec = unit_count / result[:elapsed]
  multiplier = baseline_ns_per_op ? (ns_per_op / baseline_ns_per_op) : 1.0
  asserted = if no_tracepoint
    unit_count.positive? # no handler to fire; assert the work itself ran
  elsif expected_fired_zero
    result[:fired] == 0
  else
    result[:fired] > 0
  end
  printf(
    "%-32s %14.1f ns/op %16.1f ops/sec %10.2fx   (fired=%d, asserted=%s)\n",
    result[:label], ns_per_op, ops_per_sec, multiplier, result[:fired], asserted
  )
  raise "#{result[:label]}: success assertion failed (fired=#{result[:fired]}, expected_zero=#{expected_fired_zero})" unless asserted

  ns_per_op
end

# outer = number of WORK.run calls, inner = loop size per call.
# untargeted variants get their own (larger) inner since they're cheap.
outer, inner_baseline, inner_call, inner_line, inner_untargeted = if SMOKE
  [3, 2_000, 500, 50, 500]
else
  [20, 2_000_000, 500_000, 20_000, 500_000] # global :line is ~30x, sized down accordingly
end

puts "Ruby: #{RUBY_DESCRIPTION}"
puts "Platform: #{RUBY_PLATFORM}  cores: #{Etc.nprocessors}"
puts "outer=#{outer} inner_baseline=#{inner_baseline} inner_call=#{inner_call} " \
     "inner_line=#{inner_line} inner_untargeted=#{inner_untargeted}"
puts "One iteration = Work.run(inner), a loop calling Work.step(a,b) `inner` times."
puts "ns/op below = elapsed / (outer * inner), i.e. cost per Work.step call -- " \
     "the traced unit -- so rows with different `inner` remain comparable."
puts

# --- baseline: no TracePoint at all ---
3.times { Work.run(inner_baseline) } # warmup, identical across all variants below
baseline = timed("baseline (no TracePoint)", outer) do |_bump|
  outer.times { Work.run(inner_baseline) }
end
baseline_ns = report_row(baseline, outer * inner_baseline, nil, no_tracepoint: true)

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
global_call_ns = report_row(global_call, outer * inner_call, baseline_ns)

# --- targeted :call (target: the Work.step method -- every call is a hit) ---
3.times { Work.run(inner_call) }
tc_fired = 0
tp_target_call = TracePoint.new(:call) { |_tp| tc_fired += 1 }
tp_target_call.enable(target: TARGET_METHOD)
target_call = timed("targeted :call (hot target)", outer) do |_bump|
  outer.times { Work.run(inner_call) }
end
tp_target_call.disable
target_call[:fired] = tc_fired
target_call_ns = report_row(target_call, outer * inner_call, baseline_ns)

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
global_line_ns = report_row(global_line, outer * inner_line, baseline_ns)

# --- targeted :line (target: the Work.step method -- every call is a hit) ---
3.times { Work.run(inner_line) }
tl_fired = 0
tp_target_line = TracePoint.new(:line) { |_tp| tl_fired += 1 }
tp_target_line.enable(target: TARGET_METHOD)
target_line = timed("targeted :line (hot target)", outer) do |_bump|
  outer.times { Work.run(inner_line) }
end
tp_target_line.disable
target_line[:fired] = tl_fired
target_line_ns = report_row(target_line, outer * inner_line, baseline_ns)

puts
puts "== untargeted: targeted TracePoint on a COLD method, hot loop runs untargeted =="
puts "(this is the measurement the project needs: TracePoint#enable(target:) is"
puts " supposed to be near-free on code paths that are not the target)"

# --- untargeted :call ---
3.times { Work.run(inner_untargeted) }
uc_fired = 0
tp_untargeted_call = TracePoint.new(:call) { |_tp| uc_fired += 1 }
tp_untargeted_call.enable(target: COLD_TARGET_METHOD)
untargeted_call = timed("untargeted :call", outer) do |_bump|
  outer.times { Work.run(inner_untargeted) }
end
tp_untargeted_call.disable
untargeted_call[:fired] = uc_fired
untargeted_call_ns = report_row(untargeted_call, outer * inner_untargeted, baseline_ns, expected_fired_zero: true)

# --- untargeted :line ---
3.times { Work.run(inner_untargeted) }
ul_fired = 0
tp_untargeted_line = TracePoint.new(:line) { |_tp| ul_fired += 1 }
tp_untargeted_line.enable(target: COLD_TARGET_METHOD)
untargeted_line = timed("untargeted :line", outer) do |_bump|
  outer.times { Work.run(inner_untargeted) }
end
tp_untargeted_line.disable
untargeted_line[:fired] = ul_fired
untargeted_line_ns = report_row(untargeted_line, outer * inner_untargeted, baseline_ns, expected_fired_zero: true)

puts
puts "== targeted vs global summary (per-Work.step-call cost, both already equal-unit) =="

def compare(label_a, ns_a, label_b, ns_b)
  ratio = ns_a / ns_b
  if ratio > 1.0
    printf("%s took %.2fx as long as %s (i.e. %s was slower)\n", label_a, ratio, label_b, label_a)
  elsif ratio < 1.0
    printf("%s took %.2fx as long as %s (i.e. %s was faster)\n", label_a, ratio, label_b, label_a)
  else
    printf("%s and %s took the same time\n", label_a, label_b)
  end
end

compare("targeted :call (hot target)", target_call_ns, "global :call", global_call_ns)
compare("targeted :line (hot target)", target_line_ns, "global :line", global_line_ns)
compare("untargeted :call", untargeted_call_ns, "baseline", baseline_ns)
compare("untargeted :line", untargeted_line_ns, "baseline", baseline_ns)

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
