require "test_helper"
require "canary/prefilter"
require "tempfile"

class PrefilterTest < Minitest::Test
  def test_clean_submission_has_no_findings
    report = prefilter(<<~RUBY)
      def add(a, b)
        a + b
      end
    RUBY

    assert report.syntax_valid
    refute report.truncated
    assert report.clean?
  end

  def test_structurally_invalid_submission_is_not_truncated
    report = prefilter("def foo(1, 2)\nend\n")

    refute report.syntax_valid
    refute report.truncated
    refute report.clean?
    assert(report.findings.all? { |f| f.tier == 0 })
  end

  def test_truncated_submission_is_reported_as_truncated
    report = prefilter("def foo\n  a = 1\n  if a")

    refute report.syntax_valid
    assert report.truncated
    refute report.clean?
  end

  def test_lint_tier_is_off_by_default
    report = prefilter(<<~RUBY)
      class Circle
        def area(r)
          Math::PI * r**2
        end
      end
    RUBY

    assert report.syntax_valid
    refute report.truncated
    assert report.clean?
  end

  def test_lint_finding_is_reported_when_opted_in_without_executing_the_submission
    report = prefilter(<<~RUBY, lint: true)
      def foo
        x = 1
        x = 2
        return
        puts "unreachable"
      end
    RUBY

    assert report.syntax_valid
    refute report.truncated
    refute report.clean?
    cop_names = report.findings.select { |f| f.tier == 1 }.map(&:type)
    assert_includes cop_names, "Lint/UselessAssignment"
    assert_includes cop_names, "Lint/UnreachableCode"
  end

  def test_report_carries_no_score_or_reward
    report = prefilter("def add(a, b)\n  a + b\nend\n")

    refute_respond_to report, :score
    refute_respond_to report, :reward
  end

  def test_hostile_rubocop_yml_cannot_silence_the_gate
    fixture = File.join(__dir__, "prefilter_fixtures", "hostile_rubocop_yml", "submission.rb")

    report = Canary::Prefilter.call(fixture, lint: true)

    cop_names = report.findings.select { |f| f.tier == 1 }.map(&:type)
    assert_includes cop_names, "Lint/UselessAssignment"
    assert_includes cop_names, "Lint/UnreachableCode"
  end

  private

  def prefilter(source, lint: false)
    file = Tempfile.new(%w[prefilter_submission .rb])
    file.write(source)
    file.close
    Canary::Prefilter.call(file.path, lint: lint)
  ensure
    file&.unlink
  end
end
