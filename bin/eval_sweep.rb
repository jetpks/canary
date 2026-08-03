#!/usr/bin/env ruby

require_relative "../lib/canary"
require "fileutils"
require "json"

# Runs the frozen I15 sweep shape and commits the resulting
# Canary::Eval::Record set, and the raw completions that produced them,
# under results/: all 13 tasks x k=3 x {claude-haiku-4-5-20251001,
# claude-sonnet-5} hidden, plus the same 13 tasks x k=1 x
# claude-haiku-4-5-20251001 grader-visible - 91 live calls total.
#
# Records and completions for one run live together under one
# results/run-<timestamp>/ directory, and a later run lands in its own
# fresh directory rather than overwriting an earlier one's evidence -
# results/sweep.jsonl, I15's run, is exactly the run this replaces, and it
# stays on disk untouched as a result (I15 F2: a run you can't re-score is
# a run you have to re-buy). Both files are written incrementally, as each
# record/completion lands, rather than batched at the end: an exception on
# call 90 must not cost the 89 samples already paid for.
#
# Opt-in the same way the rest of the suite is: nothing reads .env or
# spends a cent unless CANARY_LIVE=1 is set (test/test_helper.rb's own
# .env-loading gate, mirrored here rather than shared, since a test-only
# convenience has no business becoming a runtime dependency of bin/).
module EvalSweep
  HIDDEN_MODELS = ["claude-haiku-4-5-20251001", "claude-sonnet-5"].freeze
  VISIBLE_MODELS = ["claude-haiku-4-5-20251001"].freeze
  HIDDEN_K = 3
  VISIBLE_K = 1

  # $/token. Current as of 2026-08-02: Haiku 4.5 is $1/$5 per MTok in/out;
  # Sonnet 5 is $2/$10 per MTok in/out through its 2026-08-31 introductory
  # window (standard Sonnet pricing of $3/$15 starts 2026-09-01).
  PRICE_TABLE = {
    "claude-haiku-4-5-20251001" => {input_token_price: 1.0 / 1_000_000, output_token_price: 5.0 / 1_000_000},
    "claude-sonnet-5" => {input_token_price: 2.0 / 1_000_000, output_token_price: 10.0 / 1_000_000}
  }.freeze

  # Sized well above the worst case, not tight against it: 91 calls at
  # max_tokens=4096 each (Providers::Anthropic::DEFAULT_MAX_TOKENS) is
  # ~$2.73 at these prices even if every single one maxed out its budget.
  # The guard exists to catch a real runaway, not to shave the last dollar
  # off an estimate.
  SPEND_CAP_DOLLARS = 10.0

  RESULTS_DIR = File.expand_path("../results", __dir__)
  LIVE_ENV_FILE = File.expand_path("../.env", __dir__)

  def self.load_env!
    abort "CANARY_LIVE=1 is required to run the live sweep" unless ENV["CANARY_LIVE"]

    if File.exist?(LIVE_ENV_FILE)
      File.foreach(LIVE_ENV_FILE) do |line|
        next if line.lstrip.start_with?("#") || !line.include?("=")

        name, value = line.chomp.split("=", 2)
        ENV[name.strip] ||= value.strip.delete_prefix('"').delete_suffix('"')
      end
    end

    abort "CANARY_LIVE is set but no ANTHROPIC_API_KEY was loaded - is .env present?" unless ENV["ANTHROPIC_API_KEY"]
  end

  # One fresh directory per run, so a rerun supersedes rather than
  # overwrites - see the module comment.
  def self.new_run_dir
    File.join(RESULTS_DIR, Time.now.utc.strftime("run-%Y%m%dT%H%M%SZ"))
  end

  def self.run
    load_env!

    tasks = Canary::TaskRepo.all
    total_calls = (tasks.size * HIDDEN_K * HIDDEN_MODELS.size) + (tasks.size * VISIBLE_K * VISIBLE_MODELS.size)
    budget = Canary::Sampler::Budget.new(max_samples: total_calls)
    spend_guard = Canary::Sampler::SpendGuard.new(max_dollars: SPEND_CAP_DOLLARS, price_table: PRICE_TABLE)

    run_dir = new_run_dir
    FileUtils.mkdir_p(run_dir)
    records_path = File.join(run_dir, "sweep.jsonl")
    completions_path = File.join(run_dir, "completions.jsonl")

    sampler = Canary::Sampler.new(
      provider: Canary::Providers::Anthropic.new,
      budget: budget,
      record_sink: Canary::Sampler::RecordSink.new(path: completions_path),
      spend_guard: spend_guard
    )
    runner = Canary::Eval::Runner.new(sampler: sampler)
    append_record = ->(record) { File.open(records_path, "a") { |f| f.puts(JSON.generate(record.to_h)) } }

    puts "spend guard cap: $#{SPEND_CAP_DOLLARS}"
    puts "budget cap: #{total_calls} samples"
    puts "hidden arm: #{tasks.size} tasks x k=#{HIDDEN_K} x #{HIDDEN_MODELS.join(', ')}"
    hidden = runner.call(entries: tasks, models: HIDDEN_MODELS, k: HIDDEN_K, grader: false, &append_record)

    puts "grader-visible arm: #{tasks.size} tasks x k=#{VISIBLE_K} x #{VISIBLE_MODELS.join(', ')}"
    visible = runner.call(entries: tasks, models: VISIBLE_MODELS, k: VISIBLE_K, grader: true, &append_record)

    records = hidden + visible
    report_spend(records)
    write_summary(records, run_dir)
    puts "wrote #{records.size} records to #{records_path}"
    puts "wrote completions to #{completions_path}"
    records_path
  end

  def self.record_cost(record)
    return 0.0 unless record.input_tokens && record.output_tokens

    rate = PRICE_TABLE.fetch(record.model)
    (record.input_tokens * rate[:input_token_price]) + (record.output_tokens * rate[:output_token_price])
  end

  def self.report_spend(records)
    spend = records.sum { |record| record_cost(record) }
    tripped = records.any? { |record| record.non_score_reason == :spend_exceeded }
    puts "spend guard tripped: #{tripped}"
    puts format("actual spend (from recorded token usage x price table): $%.4f", spend)
  end

  def self.write_summary(records, run_dir)
    lines = ["# Canary eval sweep", ""]
    records.group_by { |record| [record.model, record.render_mode] }.sort.each do |(model, mode), arm_records|
      lines.concat(arm_section(model, mode, arm_records))
    end

    path = File.join(run_dir, "summary.md")
    File.write(path, lines.join("\n"))
    puts "wrote summary to #{path}"
    path
  end

  def self.arm_section(model, mode, arm_records)
    k = arm_records.group_by(&:task_name).values.map(&:size).max
    report = Canary::Eval::Report.new(arm_records)

    lines = ["## #{model} / #{mode}", ""]
    lines << "- scored: #{report.scored_count}, non_score: #{report.non_score_count}"
    lines << "- non_scores_by_reason: #{report.non_scores_by_reason}"
    lines << "- pass_at_1: #{report.pass_at_1.inspect} (tasks_counted: #{report.tasks_counted(1)})"
    lines << "- pass_at_#{k}: #{report.pass_at_k(k).inspect} (tasks_counted: #{report.tasks_counted(k)})" if k && k > 1
    lines << ""
    lines.concat(task_table(arm_records))
    lines << ""
  end

  def self.task_table(arm_records)
    lines = ["| task | scored | passed | non_score_reasons |", "|---|---|---|---|"]
    arm_records.group_by(&:task_name).sort.each do |task_name, task_records|
      task_report = Canary::Eval::Report.new(task_records)
      passed = task_records.count(&:passed)
      lines << "| #{task_name} | #{task_report.scored_count} | #{passed} | #{task_report.non_scores_by_reason} |"
    end
    lines
  end
end

EvalSweep.run if $PROGRAM_NAME == __FILE__
