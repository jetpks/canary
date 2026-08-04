require "test_helper"

# Proves the render surface's contract: hidden mode is the default and
# carries only the statement, grader-visible mode is opt-in and carries the
# grader, and the mechanism (category, a broken solution's misconception or
# id) never reaches either. Built on this test's own fixtures under
# prompt_fixtures/, not on tasks/**, since a concurrent lane owns tasks/**.
class PromptTest < Minitest::Test
  FIXTURES = File.expand_path("prompt_fixtures", __dir__)

  def setup
    @entry = build_entry
  end

  def test_hidden_mode_is_the_default_and_carries_the_statement
    result = Canary::Prompt.render(@entry)

    assert_equal :hidden, result.mode
    assert_includes result.text, @entry.statement
  end

  def test_hidden_mode_does_not_read_the_grader_file
    result = Canary::Prompt.render(@entry)

    refute_includes result.text, File.read(@entry.reference.test_path)
  end

  def test_grader_visible_mode_is_opt_in_and_carries_both_statement_and_grader
    result = Canary::Prompt.render(@entry, grader: true)

    assert_equal :grader_visible, result.mode
    assert_includes result.text, @entry.statement
    assert_includes result.text, File.read(@entry.reference.test_path)
  end

  def test_the_default_call_never_includes_what_grader_mode_reveals
    grader_source = File.read(@entry.reference.test_path)

    refute_includes Canary::Prompt.render(@entry).text, grader_source
  end

  def test_broken_solution_fields_never_reach_either_mode
    [Canary::Prompt.render(@entry), Canary::Prompt.render(@entry, grader: true)].each do |result|
      @entry.broken_solutions.each do |broken|
        refute_includes result.text, broken.id
        refute_includes result.text, broken.misconception
      end
    end
  end

  # Non-vacuous by construction, not by assertion: every Entry member gets
  # its own sentinel value here via Entry.members reflection rather than a
  # hardcoded field list, so a field added to Entry after this test was
  # written still gets a sentinel and is still checked below - nothing here
  # has to change for that coverage to hold. See report.md for this test
  # deliberately broken once (a leaked :category) and restored, proving the
  # loop actually fails rather than passing by omission.
  def test_hidden_mode_leaks_no_entry_field_other_than_statement
    entry = build_sentinel_entry
    text = Canary::Prompt.render(entry).text
    checked_members = Canary::TaskRepo::Entry.members - [:statement]

    nil_members = checked_members.select { |member| entry.public_send(member).nil? }
    assert_empty nil_members, "sentinel entry must supply a non-nil sentinel for every member so the leak check below isn't vacuous; nil for #{nil_members.inspect}"

    checked_members.each do |member|
      refute_includes text, entry.public_send(member).to_s, "Entry##{member} leaked into the hidden-mode prompt"
    end
  end

  private

  def build_entry
    Canary::TaskRepo::Entry.new(
      name: "widget_wrap",
      category: "return value identity",
      statement: "Implement Widget.wrap, a module method that returns Widget itself.",
      adapter: :minitest,
      reference: reference_task,
      broken_solutions: [
        Canary::TaskRepo::BrokenSolution.new(
          id: "returns_nil",
          misconception: "wrap returns nil instead of Widget itself.",
          task: broken_task("returns_nil")
        )
      ]
    )
  end

  def build_sentinel_entry
    Canary::TaskRepo::Entry.new(
      name: "SENTINEL_NAME_7c1e",
      category: "SENTINEL_CATEGORY_7c1e",
      statement: "SENTINEL_STATEMENT_7c1e is the only sentinel allowed to appear.",
      adapter: :SENTINEL_ADAPTER_7c1e,
      provenance: "SENTINEL_PROVENANCE_7c1e",
      source_attestation: "SENTINEL_SOURCE_ATTESTATION_7c1e",
      reference: reference_task,
      broken_solutions: [
        Canary::TaskRepo::BrokenSolution.new(
          id: "SENTINEL_BROKEN_ID_7c1e",
          misconception: "SENTINEL_MISCONCEPTION_7c1e",
          task: broken_task("returns_nil")
        )
      ]
    )
  end

  def reference_task
    dir = File.join(FIXTURES, "task")
    Canary::Task.new(solution_path: File.join(dir, "solution.rb"), test_path: File.join(dir, "grader.rb"), adapter: :minitest)
  end

  def broken_task(id)
    dir = File.join(FIXTURES, "task")
    Canary::Task.new(solution_path: File.join(dir, "broken", "#{id}.rb"), test_path: File.join(dir, "grader.rb"), adapter: :minitest)
  end
end
