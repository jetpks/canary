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
# Every row runs REPEATS times and reports min/median/max, not a single shot.
# Host run-to-run variance is measured separately (see the control step right
# before the `untargeted` rows below), via CONTROL_REPEATS forked child
# processes doing identical work with no TracePoint -- Process.fork gives each
# repeat its own OS scheduling entity (core, cache state, clock ramp), which is
# what turned out to matter: repeats taken back-to-back inside one process, or
# measured early in the script before it warms up, both undercounted the real
# drift. The untargeted rows' multiplier is checked against that figure before
# being printed, so a ratio close to 1.0x is reported as "within host
# variance" instead of a spuriously precise number.
#
# For the same reason, the baseline row itself is measured position-matched
# with that control -- late, after the global/targeted rows -- not first and
# cold at process start. A cold-first baseline undercounts the same host
# ramp-up, deflating every multiplier computed against it. Printing of every
# row is deferred until this baseline exists; the position each row's own
# work is actually *measured* at is unchanged from before.
#
# The `untargeted` variants are the deliverable: a TracePoint targeted at a
# COLD method (never called by the hot loop) while the hot, UNTARGETED loop
# runs at full size. This measures dispatch cost on non-target code paths,
# which `enable(target:)` is specifically designed to avoid -- as opposed to
# the `targeted` variants below, which target Work.step itself (the hot
# loop's entire body), so every call is a hit and they measure handler
# invocation cost, not dispatch cost. Both numbers are kept because they
# answer different questions.

require "etc"

SMOKE = ARGV.include?("--smoke")
REPEATS = SMOKE ? 3 : 5
# The host-variance control below needs more samples than a table row to get a
# stable min/max range (range is a noisy estimator at N=5 -- two back-to-back
# runs at N=5 gave 2.9% and 6.9% for the same host). Cheap since it reuses the
# small `inner_untargeted` work size.
CONTROL_REPEATS = SMOKE ? REPEATS : 20

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

# Runs Work.run(inner) `outer` times back to back, timing the whole batch.
# Returns [elapsed_seconds, last_return_value] -- Work.run is deterministic
# for a given `inner`, so the last call's return value is enough to check.
def measure_once(inner, outer)
  result = nil
  t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  outer.times { result = Work.run(inner) }
  t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  [t1 - t0, result]
end

def stats(values)
  sorted = values.sort
  { min: sorted.first, median: sorted[sorted.length / 2], max: sorted.last }
end

# Range (max - min) is fragile once there's enough data for a single
# scheduling outlier to show up -- observed live: one of 20 forked control
# reps got scheduled badly and its outlier alone inflated the raw range to
# +/-56.6%, which then swallowed a genuine ~2x effect (targeted vs global
# :line) into a false "no measurable difference". Trim the single highest and
# lowest sample before taking the range, once there's enough data for that to
# still be meaningful, so one bad rep can't dominate every comparison below.
def spread_pct(values)
  sorted = values.sort
  trimmed = sorted.length >= 5 ? sorted[1..-2] : sorted
  ((trimmed.max - trimmed.min) / sorted[sorted.length / 2]) * 100.0
end

# Runs Work.run(inner)-equivalent work in a forked child process, no
# TracePoint, and reports its elapsed time back over a pipe. Used only to
# measure host run-to-run variance: each fork is a distinct OS process, so
# this captures core migration / scheduling / clock-ramp drift that repeats
# inside a single process do not.
def measure_in_child(inner, outer)
  reader, writer = IO.pipe
  pid = Process.fork do
    reader.close
    outer.times { Work.run(inner) } # warmup, identical to the in-process rows
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    outer.times { Work.run(inner) }
    t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    writer.write((t1 - t0).to_s)
    writer.close
  end
  writer.close
  elapsed = reader.read.to_f
  reader.close
  Process.wait(pid)
  elapsed
end

# unit_count = total number of Work.step calls performed per repeat
# (outer * inner). ns/op and ops/sec are per Work.step call, so every row --
# regardless of its `inner` -- reports the cost of the same unit of work.
#
# repeats_data: array of REPEATS hashes {elapsed:, fired:, ok:}, one per
# repeat -- `ok` is that repeat's own success assertion (fired count or, for
# the baseline, the work's actual checksum).
def report_row(label, repeats_data, unit_count, baseline_stats: nil, host_variance_pct: nil)
  ns_values = repeats_data.map { |r| (r[:elapsed] / unit_count) * 1e9 }
  ns_stats = stats(ns_values)
  ops_per_sec = 1e9 / ns_stats[:median]

  fired_values = repeats_data.map { |r| r[:fired] }
  fired_str = fired_values.uniq.length == 1 ? fired_values.first.to_s : "#{fired_values.min}..#{fired_values.max}"
  all_ok = repeats_data.all? { |r| r[:ok] }

  multiplier_str = if baseline_stats.nil?
    "1.00x (baseline)"
  else
    ratio = ns_stats[:median] / baseline_stats[:median]
    if host_variance_pct && (ratio - 1.0).abs <= host_variance_pct / 100.0
      format("~1.00x (within +/-%.1f%% host variance)", host_variance_pct)
    else
      format("%.2fx", ratio)
    end
  end

  printf(
    "%-32s min=%8.1f median=%8.1f max=%8.1f ns/op   ops/sec(median)=%13.1f   %-34s (fired=%s, asserted=%s)\n",
    label, ns_stats[:min], ns_stats[:median], ns_stats[:max], ops_per_sec, multiplier_str, fired_str, all_ok
  )
  raise "#{label}: success assertion failed on at least one of #{REPEATS} repeats (fired=#{fired_str})" unless all_ok

  ns_stats
end

# outer = number of Work.run calls, inner = loop size per call.
# untargeted variants get their own (larger) inner since they're cheap.
outer, inner_baseline, inner_call, inner_line, inner_untargeted = if SMOKE
  [3, 2_000, 500, 50, 500]
else
  [20, 2_000_000, 500_000, 20_000, 500_000] # global :line is ~30x, sized down accordingly
end

puts "Ruby: #{RUBY_DESCRIPTION}"
puts "Platform: #{RUBY_PLATFORM}  cores: #{Etc.nprocessors}"
puts "outer=#{outer} inner_baseline=#{inner_baseline} inner_call=#{inner_call} " \
     "inner_line=#{inner_line} inner_untargeted=#{inner_untargeted}  REPEATS=#{REPEATS}"
puts "One iteration = Work.run(inner), a loop calling Work.step(a,b) `inner` times."
puts "Each row runs REPEATS=#{REPEATS} independent repeats and reports min/median/max."
puts "ns/op below = elapsed / (outer * inner), i.e. cost per Work.step call -- " \
     "the traced unit -- so rows with different `inner` remain comparable."
puts

# --- global :call, targeted :call, global :line, targeted :line ---
# Measured here (position unchanged from before), but NOT yet printed: the
# baseline they'll be compared against is measured further down, in the same
# spot as the host-variance control below, and printing is deferred until
# that position-matched baseline exists. See the position-matching note above
# the baseline block for why -- measuring the baseline first, cold, at
# process start is exactly the bug being fixed here.
3.times { Work.run(inner_call) }
global_call_repeats = Array.new(REPEATS) do
  fired = 0
  tp = TracePoint.new(:call) { |_tp| fired += 1 }
  tp.enable
  elapsed, = measure_once(inner_call, outer)
  tp.disable
  { elapsed: elapsed, fired: fired, ok: fired > 0 }
end

# --- targeted :call (target: the Work.step method -- every call is a hit) ---
3.times { Work.run(inner_call) }
target_call_repeats = Array.new(REPEATS) do
  fired = 0
  tp = TracePoint.new(:call) { |_tp| fired += 1 }
  tp.enable(target: TARGET_METHOD)
  elapsed, = measure_once(inner_call, outer)
  tp.disable
  { elapsed: elapsed, fired: fired, ok: fired > 0 }
end

# --- global :line ---
3.times { Work.run(inner_line) }
global_line_repeats = Array.new(REPEATS) do
  fired = 0
  tp = TracePoint.new(:line) { |_tp| fired += 1 }
  tp.enable
  elapsed, = measure_once(inner_line, outer)
  tp.disable
  { elapsed: elapsed, fired: fired, ok: fired > 0 }
end

# --- targeted :line (target: the Work.step method -- every call is a hit) ---
3.times { Work.run(inner_line) }
target_line_repeats = Array.new(REPEATS) do
  fired = 0
  tp = TracePoint.new(:line) { |_tp| fired += 1 }
  tp.enable(target: TARGET_METHOD)
  elapsed, = measure_once(inner_line, outer)
  tp.disable
  { elapsed: elapsed, fired: fired, ok: fired > 0 }
end

# --- baseline: no TracePoint at all ---
# Measured HERE -- after the four rows above, at the same position in the
# process as the host-variance control right below it -- rather than first
# and cold at process start. A cold-first baseline undercounts host/CPU
# ramp-up (measured live on this host: identical work re-measured late in the
# same process came in at 0.81x/0.77x/0.75x of a cold-first measurement, i.e.
# position alone is worth ~25% here), which deflates every multiplier
# computed against it and is what let the untargeted rows print a physically
# impossible "faster than baseline" result. Printing for every row above is
# deferred to below, now that this position-matched baseline_stats exists.
baseline_checksum = (inner_baseline * (inner_baseline - 1)) / 2
3.times { Work.run(inner_baseline) } # warmup, identical across all variants above/below
baseline_repeats = Array.new(REPEATS) do
  elapsed, result = measure_once(inner_baseline, outer)
  { elapsed: elapsed, fired: 0, ok: result == baseline_checksum }
end
baseline_stats = report_row("baseline (no TracePoint, position-matched late)", baseline_repeats, outer * inner_baseline)
puts

global_call_stats = report_row("global :call", global_call_repeats, outer * inner_call,
  baseline_stats: baseline_stats)
target_call_stats = report_row("targeted :call (hot target)", target_call_repeats, outer * inner_call,
  baseline_stats: baseline_stats)
global_line_stats = report_row("global :line", global_line_repeats, outer * inner_line,
  baseline_stats: baseline_stats)
target_line_stats = report_row("targeted :line (hot target)", target_line_repeats, outer * inner_line,
  baseline_stats: baseline_stats)

puts

# --- host run-to-run variance control ---
# No TracePoint, repeated in CONTROL_REPEATS separate forked processes rather
# than back-to-back in this one -- each fork is its own OS scheduling entity,
# which is where the real drift showed up (see header comment). Measured here,
# right before the untargeted rows it validates, rather than up front: this
# process has already run several seconds of sustained TracePoint work by this
# point, and that position turned out to matter -- a control measured before
# that warm-up understated the noise floor these rows actually see.
control_ns = Array.new(CONTROL_REPEATS) { measure_in_child(inner_untargeted, outer) / (outer * inner_untargeted) * 1e9 }
control_stats = stats(control_ns)
raw_variance_pct = ((control_stats[:max] - control_stats[:min]) / control_stats[:median]) * 100.0
host_variance_pct = spread_pct(control_ns)
puts format(
  "Host run-to-run variance control (%d separate forked processes, identical work / no " \
  "TracePoint, measured at this point in the run): raw min=%.1f median=%.1f max=%.1f ns/op " \
  "(+/-%.1f%%); using +/-%.1f%% (top/bottom rep trimmed, guards against a single scheduling " \
  "outlier) for the comparisons below",
  CONTROL_REPEATS, control_stats[:min], control_stats[:median], control_stats[:max],
  raw_variance_pct, host_variance_pct
)
puts

puts "== untargeted: targeted TracePoint on a COLD method, hot loop runs untargeted =="
puts "(this is the measurement the project needs: TracePoint#enable(target:) is"
puts " supposed to be near-free on code paths that are not the target)"

# --- untargeted :call ---
3.times { Work.run(inner_untargeted) }
untargeted_call_repeats = Array.new(REPEATS) do
  fired = 0
  tp = TracePoint.new(:call) { |_tp| fired += 1 }
  tp.enable(target: COLD_TARGET_METHOD)
  elapsed, = measure_once(inner_untargeted, outer)
  tp.disable
  { elapsed: elapsed, fired: fired, ok: fired == 0 }
end
untargeted_call_stats = report_row("untargeted :call", untargeted_call_repeats, outer * inner_untargeted,
  baseline_stats: baseline_stats, host_variance_pct: host_variance_pct)

# --- untargeted :line ---
3.times { Work.run(inner_untargeted) }
untargeted_line_repeats = Array.new(REPEATS) do
  fired = 0
  tp = TracePoint.new(:line) { |_tp| fired += 1 }
  tp.enable(target: COLD_TARGET_METHOD)
  elapsed, = measure_once(inner_untargeted, outer)
  tp.disable
  { elapsed: elapsed, fired: fired, ok: fired == 0 }
end
untargeted_line_stats = report_row("untargeted :line", untargeted_line_repeats, outer * inner_untargeted,
  baseline_stats: baseline_stats, host_variance_pct: host_variance_pct)

puts
puts "== targeted vs global summary (per-Work.step-call cost, both already equal-unit) =="

def compare(label_a, stats_a, label_b, stats_b, host_variance_pct)
  ratio = stats_a[:median] / stats_b[:median]
  if (ratio - 1.0).abs <= host_variance_pct / 100.0
    printf("%s and %s: no measurable difference (within +/-%.1f%% host variance)\n",
      label_a, label_b, host_variance_pct)
  elsif ratio > 1.0
    printf("%s took %.2fx as long as %s (i.e. %s was slower)\n", label_a, ratio, label_b, label_a)
  else
    printf("%s took %.2fx as long as %s (i.e. %s was faster)\n", label_a, ratio, label_b, label_a)
  end
end

compare("targeted :call (hot target)", target_call_stats, "global :call", global_call_stats, host_variance_pct)
compare("targeted :line (hot target)", target_line_stats, "global :line", global_line_stats, host_variance_pct)
compare("untargeted :call", untargeted_call_stats, "baseline", baseline_stats, host_variance_pct)
compare("untargeted :line", untargeted_line_stats, "baseline", baseline_stats, host_variance_pct)

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
