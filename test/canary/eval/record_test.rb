require "test_helper"

# Proves Canary::Eval::Record's own contract: #scored? reads the scored
# field, and the shape is a plain Struct with no required fields beyond
# whatever the caller supplies (Canary::Eval::Report and the results-schema
# gate build records with only a handful of keys set).
class RecordTest < Minitest::Test
  def test_scored_predicate_reads_the_scored_field
    scored = Canary::Eval::Record.new(scored: true)
    unscored = Canary::Eval::Record.new(scored: false)

    assert scored.scored?
    refute unscored.scored?
  end

  def test_fields_not_supplied_default_to_nil
    record = Canary::Eval::Record.new(schema_version: 1, task_name: "t", model: "m", sample_index: 0, render_mode: :hidden, scored: false, non_score_reason: :truncated)

    assert_nil record.passed
    assert_nil record.prefilter_clean
    assert_nil record.coverage_fraction
  end
end
