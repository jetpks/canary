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

  # RuboCop's Lint department ships every cop at :warning severity by
  # default (verified live: RuboCop::ConfigLoader.default_configuration has
  # zero Lint/* cops above :warning in rubocop-1.88.2) - Lint/UselessAssignment
  # and Lint/UnreachableCode are visible findings, not a gate, same as any
  # other warning-severity diagnostic.
  def test_lint_finding_is_reported_but_does_not_gate_when_opted_in
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
    assert report.clean?
    cop_names = report.findings.select { |f| f.tier == 1 }.map(&:type)
    assert_includes cop_names, "Lint/UselessAssignment"
    assert_includes cop_names, "Lint/UnreachableCode"
  end

  def test_warnings_only_submission_is_syntax_valid_with_visible_findings_and_clean
    report = prefilter(<<~RUBY)
      def foo
        x = 1
        x = 2
      end
    RUBY

    assert report.syntax_valid
    refute report.truncated
    assert report.clean?
    assert report.findings.any? { |f| f.tier == 0 && f.type == :unused_local_variable },
      "expected a visible, non-gating tier-0 warning finding, got #{report.findings.map(&:type)}"
  end

  # Tier 1's gating threshold (:error/:fatal) is not reachable through the
  # public Prefilter.call surface in this repo: every RuboCop cop defaults
  # below :error (see the comment above), and the only place severity could
  # be raised - a submission's own .rubocop.yml - is deliberately ignored by
  # the pinned ConfigStore (test_hostile_rubocop_yml_cannot_silence_the_gate
  # below). So this exercises the actual conversion Prefilter uses
  # (#finding_from_offense) directly, against a real RuboCop::Cop::Offense
  # (RuboCop's own class and its own public NO_LOCATION pseudo-location, not
  # a test double).
  def test_tier1_gates_only_at_error_or_fatal_severity
    instance = Canary::Prefilter.new(__FILE__, lint: true)

    %i[error fatal].each do |severity|
      offense = RuboCop::Cop::Offense.new(severity, RuboCop::Cop::Offense::NO_LOCATION, "msg", "Lint/Fake")
      assert instance.send(:finding_from_offense, offense).gating?, "#{severity} should gate"
    end

    %i[warning convention refactor info].each do |severity|
      offense = RuboCop::Cop::Offense.new(severity, RuboCop::Cop::Offense::NO_LOCATION, "msg", "Lint/Fake")
      refute instance.send(:finding_from_offense, offense).gating?, "#{severity} should not gate"
    end
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
