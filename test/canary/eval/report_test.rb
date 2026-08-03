require "test_helper"

# Proves Canary::Eval::Report's one load-bearing rule (R3): a non-score never
# enters a rate's denominator, and a rate over zero scored records is nil,
# not 0.0. Also proves pass@k against the unbiased Chen et al. 2021
# estimator by hand for a case simple enough to check by inspection.
class ReportTest < Minitest::Test
  def test_non_scores_are_excluded_from_every_denominator
    records = [
      record(task: "a", scored: true, passed: true),
      record(task: "a", scored: true, passed: false),
      record(task: "a", scored: false, reason: :truncated),
      record(task: "a", scored: false, reason: :refusal),
      record(task: "a", scored: false, reason: :extractor_refusal),
      record(task: "a", scored: false, reason: :truncated),
    ]
    report = Canary::Eval::Report.new(records)

    assert_equal 2, report.scored_count
    assert_equal 4, report.non_score_count
    assert_equal({truncated: 2, refusal: 1, extractor_refusal: 1}, report.non_scores_by_reason)
    assert_in_delta 0.5, report.pass_at_1, 1e-9
  end

  def test_an_all_non_score_report_yields_nil_rates_not_zero
    report = Canary::Eval::Report.new([record(task: "a", scored: false, reason: :truncated)])

    assert_equal 0, report.scored_count
    assert_nil report.pass_at_1
    assert_nil report.pass_at_k(3)
  end

  # Task "a": 3 samples, 2 passed (c=2, n=3). Task "b": 3 samples, 0 passed
  # (c=0, n=3). Chen et al. 2021: pass@k = 1 - C(n-c,k)/C(n,k).
  #
  # a: 1 - C(1,2)/C(3,2) = 1 - 0/3   = 1.0 (fewer than k failures - certain)
  # b: 1 - C(3,2)/C(3,2) = 1 - 3/3   = 0.0 (no passes at all - certain miss)
  # average = 0.5
  def test_pass_at_k_matches_the_unbiased_estimator_by_hand
    records = [
      record(task: "a", scored: true, passed: true),
      record(task: "a", scored: true, passed: true),
      record(task: "a", scored: true, passed: false),
      record(task: "b", scored: true, passed: false),
      record(task: "b", scored: true, passed: false),
      record(task: "b", scored: true, passed: false),
    ]
    report = Canary::Eval::Report.new(records)

    assert_in_delta 0.5, report.pass_at_k(2), 1e-9
  end

  # A task with fewer scored samples than k has no defined pass@k and is
  # dropped from the average rather than treated as a certain miss.
  def test_pass_at_k_skips_tasks_with_fewer_scored_samples_than_k
    records = [
      record(task: "a", scored: true, passed: true),
      record(task: "a", scored: true, passed: true),
      record(task: "b", scored: true, passed: true),
    ]
    report = Canary::Eval::Report.new(records)

    assert_in_delta 1.0, report.pass_at_k(2), 1e-9
  end

  private

  def record(task:, scored:, passed: nil, reason: nil)
    Canary::Eval::Record.new(
      schema_version: 1, task_name: task, model: "m", sample_index: 0, render_mode: :hidden,
      scored: scored, non_score_reason: reason, passed: passed
    )
  end
end
