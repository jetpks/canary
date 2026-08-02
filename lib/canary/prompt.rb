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
    Result = Struct.new(:text, :mode, keyword_init: true)

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
      return Result.new(text: grader_visible_text(entry.statement, File.read(entry.reference.test_path)), mode: :grader_visible) if grader

      Result.new(text: hidden_text(entry.statement), mode: :hidden)
    end

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
