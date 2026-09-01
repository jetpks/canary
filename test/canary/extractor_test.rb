require "test_helper"
require "json"

# Proves Canary::Extractor's contract against the four real live-sample
# responses under extractor_fixtures/ (none of which is executable Ruby as
# written - every one is fenced markdown) plus each named disposition for
# the markdown shapes those four don't cover: no fence, a fence tagged for
# another language, an untagged fence, and one truncated mid-block.
class ExtractorTest < Minitest::Test
  FIXTURES = File.expand_path("extractor_fixtures", __dir__)

  Dir[File.join(FIXTURES, "*.jsonl")].sort.each do |path|
    model = File.basename(path, ".jsonl").tr("-", "_").tr(".", "_")

    define_method("test_recovers_parseable_memoizer_from_#{model}") do
      result = Canary::Extractor.call(fixture_text(path))

      assert_equal :ok, result.outcome
      refute_nil result.code
      assert_match(/(class|module)\s+Memoizer/, result.code)
      RubyVM::AbstractSyntaxTree.parse(result.code)
    end
  end

  def test_first_ruby_block_wins_over_a_longer_later_block
    result = Canary::Extractor.call(<<~MD)
      ```ruby
      module Memoizer
      end
      ```

      Usage:

      ```ruby
      really_long_line_1 = 1
      really_long_line_2 = 2
      really_long_line_3 = 3
      really_long_line_4 = 4
      ```
    MD

    assert_equal :ok, result.outcome
    assert_equal "module Memoizer\nend", result.code
  end

  # Only emptiness refuses without a fence now. Text that isn't valid Ruby is a
  # submission the verifier fails, not an absence of one.
  def test_only_an_empty_answer_refuses_without_a_fence
    ["", "   ", "\n\n"].each do |empty|
      result = Canary::Extractor.call(empty)

      assert_equal :no_fenced_code, result.outcome, "#{empty.inspect} was accepted as code"
      assert_nil result.code
    end
  end

  def test_a_fence_tagged_a_different_language_is_refused_not_guessed
    result = Canary::Extractor.call(<<~MD)
      ```python
      def wrap(): pass
      ```
    MD

    assert_equal :no_ruby_fence, result.outcome
    assert_nil result.code
  end

  def test_an_untagged_fence_is_treated_as_ruby
    result = Canary::Extractor.call(<<~MD)
      ```
      module Memoizer
      end
      ```
    MD

    assert_equal :ok, result.outcome
    assert_equal "module Memoizer\nend", result.code
  end

  def test_an_unclosed_fence_is_extracted_as_best_effort_ok
    text = "```ruby\nmodule Memoizer\n  def self.wrap(&computation)\n    computation"

    result = Canary::Extractor.call(text)

    assert_equal :ok, result.outcome
    assert_equal "module Memoizer\n  def self.wrap(&computation)\n    computation", result.code
  end

  def test_an_unclosed_fence_in_another_language_is_still_refused
    result = Canary::Extractor.call("```python\ndef wrap():")

    assert_equal :no_ruby_fence, result.outcome
    assert_nil result.code
  end

  # ── Unfenced answers (:bare_ruby) ─────────────────────────────────────────
  # A model that writes the right code and skips the fence was failing the
  # packaging, not the task. Measured 2026-09-01: nemotron-3-super lost 83 of
  # 132 samples to :no_fenced_code, and 82 of those were bare valid Ruby.

  def test_an_unfenced_ruby_definition_is_accepted_as_bare_ruby
    source = <<~RUBY.chomp
      class Money
        def initialize(cents)
          @cents = cents
        end
      end
    RUBY

    result = Canary::Extractor.call(source)

    assert_equal :bare_ruby, result.outcome
    assert_equal source, result.code
  end

  def test_a_bare_method_definition_is_accepted
    result = Canary::Extractor.call("def fib(n)\n  n < 2 ? n : fib(n - 1) + fib(n - 2)\nend")

    assert_equal :bare_ruby, result.outcome
  end

  # Unfenced text that isn't a Ruby definition is still SUBMITTED — it just
  # carries the :bare_malformed label so a later reader can tell it apart from
  # a clean unfenced answer. The verifier fails it; the extractor does not
  # excuse it. Prose lands here because bare words chain into method calls, so
  # "no fenced code here at all" is syntactically valid Ruby that defines
  # nothing — parsing alone was never a strong enough test to sort answers
  # from sentences, which is why the label exists rather than a second gate.
  def test_unfenced_non_ruby_is_submitted_as_malformed_not_refused
    ["no fenced code here at all",
     "OK",
     "I cannot help with that request",
     "def broken(  # unclosed"].each do |text|
      result = Canary::Extractor.call(text)

      assert_equal :bare_malformed, result.outcome, "#{text.inspect} was refused"
      assert_equal text.strip, result.code
    end
  end

  # The distinction the label buys: this one IS clean Ruby, just unfenced.
  def test_a_clean_unfenced_definition_is_bare_ruby_not_malformed
    assert_equal :bare_ruby, Canary::Extractor.call("def a\n  1\nend").outcome
  end

  # The fallback is for answers with NO fence. A response that fenced
  # something tagged for another language made a choice, and :no_ruby_fence
  # stays the honest reading of it even when bare Ruby sits outside the fence.
  def test_a_non_ruby_fence_is_not_rescued_by_bare_ruby
    result = Canary::Extractor.call("def helper\n  1\nend\n\n```python\ndef wrap():\n  pass\n```")

    assert_equal :no_ruby_fence, result.outcome
    assert_nil result.code
  end

  def test_accepted_outcomes_are_the_gradable_shapes
    assert_equal %i[ok bare_ruby bare_malformed], Canary::Extractor::ACCEPTED
  end

  private

  def fixture_text(path)
    record = JSON.parse(File.read(path).lines.first)
    record.dig("response", "content").select { |block| block["type"] == "text" }.map { |block| block["text"] }.join
  end
end
