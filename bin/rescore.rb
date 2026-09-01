#!/usr/bin/env ruby

require_relative "../lib/canary"
require "json"
require "tempfile"
require "time"

# Re-grades committed runs against the CURRENT extractor, without buying a
# single new sample.
#
# I15 F2 states the principle this exists to honour: "a run you can't re-score
# is a run you have to re-buy." Every run dir keeps completions.jsonl beside
# its records, so an extractor change is answerable from disk. Before this,
# nothing read that back, and the only way to learn what a parsing change did
# was to pay for the sweep again.
#
# It never overwrites. A rescore lands as a SIDECAR in the run's own directory
# (rescore-<utc>.jsonl plus a manifest), because no new inference happened and
# minting a fresh run-<timestamp>/ would claim otherwise. The original records
# stay byte-identical, so any table can be rebuilt either way and a mixed
# reading is always detectable.
#
# Only samples whose extraction outcome actually CHANGED are re-graded; every
# other record is copied through verbatim. That keeps the cost proportional to
# the change rather than to the corpus, and means an unaffected arm's numbers
# are provably untouched rather than merely equal.
#
#   bin/rescore.rb results/run-20260901T211347Z [more run dirs...]
#   bin/rescore.rb --all
module Rescore
  REFUSAL_OUTCOMES = %w[no_fenced_code no_ruby_fence].freeze

  module_function

  def run(dirs)
    stamp = Time.now.utc.strftime("%Y%m%dT%H%M%SZ")
    repo  = Canary::TaskRepo.new
    entries = repo.all.to_h { |e| [e.name, e] }
    verifier = Canary::Verifier.new

    dirs.each { |dir| rescore_dir(dir, entries, verifier, stamp) }
  end

  def rescore_dir(dir, entries, verifier, stamp)
    records = read_jsonl(File.join(dir, "sweep.jsonl"))
    completions = read_jsonl(File.join(dir, "completions.jsonl"))
    return puts("  #{File.basename(dir)}: no records, skipped") if records.empty?

    texts = completions.to_h { |c| [key(c), content_of(c)] }
    model = records.first["model"]

    changed = []
    updated = records.map do |record|
      next record unless REFUSAL_OUTCOMES.include?(record["extractor_outcome"])

      text = texts[key(record)]
      next record if text.nil? || text.empty?

      extracted = Canary::Extractor.call(text)
      next record unless Canary::Extractor::ACCEPTED.include?(extracted.outcome)

      entry = entries[record["task_name"]]
      next record if entry.nil?

      changed << record["task_name"]
      regrade(record, extracted, entry, verifier)
    end

    report(dir, model, records, updated, changed)
    write_sidecar(dir, stamp, model, records, updated, changed)
  end

  def regrade(record, extracted, entry, verifier)
    Tempfile.create(["canary_rescore_", ".rb"]) do |file|
      file.write(extracted.code)
      file.flush
      task = Canary::Task.new(solution_path: file.path, test_path: entry.reference.test_path, adapter: entry.adapter)
      result = verifier.call(task)

      record.merge(
        "extractor_outcome" => extracted.outcome.to_s,
        "scored" => !result.prefilter_report.truncated,
        "non_score_reason" => result.prefilter_report.truncated ? record["non_score_reason"] : nil,
        "passed" => result.prefilter_report.truncated ? nil : result.passed,
        "prefilter_clean" => result.prefilter_report.clean?,
        "rollout_outcome" => result.rollout_result&.outcome&.to_s,
        "passed_examples" => result.rollout_result&.passed,
        "total_examples" => result.rollout_result&.total,
      )
    end
  end

  def report(dir, model, before, after, changed)
    b = tally(before)
    a = tally(after)
    puts format("  %-30s %s", model, File.basename(dir))
    puts format("    re-graded %d sample(s); scored %d -> %d; passed %d -> %d; pass rate %s -> %s",
      changed.size, b[:scored], a[:scored], b[:passed], a[:passed],
      pct(b[:passed], b[:scored]), pct(a[:passed], a[:scored]))
  end

  def write_sidecar(dir, stamp, model, before, after, changed)
    return if changed.empty?

    path = File.join(dir, "rescore-#{stamp}.jsonl")
    File.write(path, after.map { |r| JSON.generate(r) }.join("\n") + "\n")
    File.write(File.join(dir, "rescore-#{stamp}.json"), JSON.pretty_generate(
      "rescored_at" => stamp, "model" => model, "records" => after.size,
      "regraded" => changed.size, "tasks" => changed.tally,
      "before" => tally(before), "after" => tally(after),
      "reason" => "re-extracted with Canary::Extractor accepting #{Canary::Extractor::ACCEPTED.join('/')}",
    ))
    puts "    wrote #{File.basename(path)}"
  end

  def tally(records)
    scored = records.count { |r| r["scored"] }
    { scored: scored, passed: records.count { |r| r["passed"] }, total: records.size }
  end

  def pct(n, d) = d.zero? ? "n/a" : format("%.1f%%", 100.0 * n / d)
  def key(hash) = [hash["task_name"], hash["sample_index"]]

  def read_jsonl(path)
    return [] unless File.exist?(path)

    File.readlines(path).reject { |l| l.strip.empty? }.map { |l| JSON.parse(l) }
  end

  # Anthropic content-block responses and OpenAI message responses both appear
  # in committed runs, so both shapes are read here rather than assuming one.
  def content_of(completion)
    response = completion["response"]
    return "" unless response.is_a?(Hash)

    oai = response.dig("choices", 0, "message", "content")
    return oai if oai.is_a?(String)

    blocks = response["content"]
    return "" unless blocks.is_a?(Array)

    blocks.select { |b| b["type"] == "text" }.map { |b| b["text"] }.join
  end
end

dirs = ARGV.include?("--all") ? Dir.glob("results/run-*").sort : ARGV
abort "usage: bin/rescore.rb <run-dir>... | --all" if dirs.empty?
Rescore.run(dirs)
