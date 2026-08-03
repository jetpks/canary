require "prism"
require "rubocop"

module Canary
  # A static prefilter: inspects a submission WITHOUT executing it and
  # reports structured findings. It exists to reject what can be rejected
  # for free, before a rollout is paid for - it never scores or grades.
  #
  # A finding's severity decides whether it gates a rollout, never the tool
  # that emitted it. Tier 0 (Prism.parse) is in-process, pays only parse
  # cost, and is always on - it gates only on parse.errors; parse.warnings
  # stay visible in +findings+ but never gate. Tier 1 (RuboCop's Lint
  # department, in-process) is OPT-IN via `lint: true` and off by default,
  # and gates only at :error/:fatal severity - RuboCop's Lint department
  # ships every cop at :warning by default, so opting in surfaces findings
  # (e.g. `Math::PI * r**2` under Lint/AmbiguousOperatorPrecedence) without
  # gating on them, which is this rule's intent, not a gap in it. Style
  # linting stays behind the flag because the pinned ConfigStore below is a
  # security control, not just linting infrastructure.
  class Prefilter
    # The config RuboCop's Lint cops run under is pinned to canary's own
    # .rubocop.yml (see .config_store) rather than resolved by walking up
    # from the submission - a submission shipping its own .rubocop.yml would
    # otherwise silence the very gate judging it, and RuboCop config supports
    # `require:`, which would run arbitrary Ruby inside this process.
    CONFIG_PATH = File.expand_path("../../.rubocop.yml", __dir__)
    RUBOCOP_OPTIONS = { formatters: [], only: ["Lint"] }.freeze

    # The only RuboCop severities (RuboCop::Cop::Severity::NAMES runs
    # info < refactor < convention < warning < error < fatal) a tier 1
    # finding gates on.
    GATING_SEVERITIES = %i[error fatal].freeze

    # tier is 0 (Prism) or 1 (RuboCop). severity and type are the
    # underlying tool's own vocabulary, passed through unmodified. +gating+
    # is Prefilter's own verdict, computed from severity, not from which
    # tool emitted the finding: tier 0 gates only on parse.errors, never
    # parse.warnings; tier 1 gates only at GATING_SEVERITIES.
    Finding = Struct.new(:tier, :severity, :type, :message, :location, :gating, keyword_init: true) do
      def gating?
        gating
      end
    end

    # +truncated+ is true only when the submission failed to parse because
    # it ends mid-construct - a generation cut short, not one that is
    # structurally broken partway through.
    Report = Struct.new(:syntax_valid, :truncated, :findings, keyword_init: true) do
      # A diagnostic's severity decides whether it gates, never the tool
      # that emitted it (I16 F1: folding parse.warnings in with
      # parse.errors here hard-rejected submissions Prism itself parsed
      # fine). Non-gating findings (parse warnings, sub-:error offenses)
      # stay in +findings+ as visible signal but never flip this to false.
      def clean?
        findings.none?(&:gating?)
      end
    end

    # Collects offenses from RuboCop::Runner#file_finished instead of
    # round-tripping through a formatter and its JSON encoding - the same
    # hook RuboCop's own RuboCop::Lsp::StdinRunner uses.
    class OffenseCollector < RuboCop::Runner
      attr_reader :offenses

      def initialize(options, config_store)
        super
        @offenses = []
      end

      private

      def file_finished(_file, offenses)
        @offenses = offenses
      end
    end

    def self.call(submission_path, lint: false)
      new(submission_path, lint: lint).call
    end

    # Shared across calls: parsing .rubocop.yml on every submission would
    # undercut the whole point of going in-process. ConfigStore#for_dir
    # short-circuits to this pinned config for any directory once set, so
    # sharing it across submissions in different directories is safe.
    def self.config_store
      @config_store ||= RuboCop::ConfigStore.new.tap { |store| store.options_config = CONFIG_PATH }
    end

    def initialize(submission_path, lint: false)
      @submission_path = submission_path
      @source = File.read(submission_path)
      @lint = lint
    end

    def call
      parse = Prism.parse(@source)
      findings = tier0_findings(parse)
      findings.concat(tier1_findings) if @lint && parse.success?

      Report.new(syntax_valid: parse.success?, truncated: truncated?(parse), findings: findings)
    end

    private

    def tier0_findings(parse)
      diagnostic_findings(parse.errors, gating: true) + diagnostic_findings(parse.warnings, gating: false)
    end

    def diagnostic_findings(diagnostics, gating:)
      diagnostics.map do |diagnostic|
        Finding.new(
          tier: 0,
          severity: diagnostic.level,
          type: diagnostic.type,
          message: diagnostic.message,
          location: diagnostic_location(diagnostic.location),
          gating: gating
        )
      end
    end

    # Prism::ParseResult#continuable? does not exist until prism 1.10; this
    # Ruby ships prism 1.9.0 (verified via Prism::VERSION). irb 1.18.0's
    # RubyLex hits the same gap and falls back to message heuristics
    # (lib/irb/ruby-lex.rb#check_syntax_error_heuristics). We use a simpler
    # signal sufficient for whole-file truncation detection: a generation
    # cut off mid-construct always leaves at least one error anchored at
    # end-of-source, because the parser ran out of input before it could
    # close whatever was still open. A submission broken somewhere in its
    # middle does not.
    def truncated?(parse)
      return false if parse.success?

      eof = @source.bytesize
      parse.errors.any? { |error| error.location.end_offset == eof }
    end

    def tier1_findings
      runner = OffenseCollector.new(RUBOCOP_OPTIONS, self.class.config_store)
      runner.run([@submission_path])
      runner.offenses.map { |offense| finding_from_offense(offense) }
    end

    def finding_from_offense(offense)
      Finding.new(
        tier: 1,
        severity: offense.severity.name,
        type: offense.cop_name,
        message: offense.message,
        location: offense_location(offense),
        gating: GATING_SEVERITIES.include?(offense.severity.name)
      )
    end

    def diagnostic_location(location)
      "#{@submission_path}:#{location.start_line}:#{location.start_column}"
    end

    def offense_location(offense)
      "#{@submission_path}:#{offense.line}:#{offense.real_column}"
    end
  end
end
