module Canary
  # The model-facing render surface: statement in, prompt text out. This is
  # structural, not a filter - +render+ pulls exactly one field off +entry+
  # (+statement+, plus the reference grader's file contents when
  # +grader: true+) before anything else runs, and every private builder
  # below takes only those bare strings, never the Entry itself. category,
  # broken_solutions, and a broken solution's misconception/id name the
  # task's trap mechanism; a builder that never receives Entry cannot leak
  # them, regardless of what fields Entry grows next.
  #
  # Hidden mode is the default per this project's methodology: the model
  # sees the statement and nothing else from meta.yml. Grader-visible mode
  # is diagnostic only, for measuring per-task grader strength later - never
  # the default, and it is the only mode that reads the grader file.
  class Prompt
    Result = Data.define(:text, :system, :mode)

    # The output contract, stated to the model instead of assumed of it.
    #
    # Extractor requires a fenced Ruby block (:no_fenced_code /
    # :no_ruby_fence) but nothing ever asked for one, so part of what a
    # hidden-arm score measured was whether a model happened to guess this
    # harness's convention. That is not Ruby tail-generalization, and it is
    # biased against exactly the weaker models the corpus exists to
    # discriminate among: a model that cannot clear the format lottery
    # cannot be measured at all, which gives the instrument a floor rather
    # than a scale. Measured 2026-08-31: one Flash-Next derivative answered
    # a bare task statement with <tool_call><function=list_files> on 27 of
    # 30 samples, scoring 0 usable data points on tasks it can actually do.
    #
    # The no-tools sentence is load-bearing, not decoration - that drift is
    # what it addresses. Shared across both render modes on purpose: the
    # output contract is the same experiment either way, and only the
    # task-framing content differs, which is what the preambles carry.
    SYSTEM = <<~TEXT.freeze
      You are completing a self-contained Ruby coding task.

      Reply with exactly one fenced Ruby code block containing the complete
      implementation, and nothing else - no prose before or after it.

      You have no tools, no filesystem access, and no shell. Do not emit
      tool calls; write the code directly.
    TEXT

    HIDDEN_PREAMBLE = <<~TEXT.freeze
      You are given a Ruby task. Implement it so the task's test suite passes.

      Task:
    TEXT

    GRADER_VISIBLE_PREAMBLE = <<~TEXT.freeze
      You are given a Ruby task and the test suite that grades it. Implement
      the task so this test suite passes.

      Task:
    TEXT

    def self.render(entry, grader: false)
      return hidden(entry.statement) unless grader

      Result.new(
        text: grader_visible_text(entry.statement, File.read(entry.reference.test_path)),
        system: SYSTEM, mode: :grader_visible
      )
    end

    def self.hidden(statement)
      Result.new(text: hidden_text(statement), system: SYSTEM, mode: :hidden)
    end
    private_class_method :hidden

    def self.hidden_text(statement)
      "#{HIDDEN_PREAMBLE}#{statement}\n"
    end
    private_class_method :hidden_text

    def self.grader_visible_text(statement, grader_source)
      "#{GRADER_VISIBLE_PREAMBLE}#{statement}\n\nTest suite:\n\n#{grader_source}\n"
    end
    private_class_method :grader_visible_text
  end
end
