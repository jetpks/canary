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

  def test_no_fence_at_all_is_a_distinguishable_refusal
    result = Canary::Extractor.call("Sure, here is Memoizer: module Memoizer; end")

    assert_equal :no_fenced_code, result.outcome
    assert_nil result.code
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

  private

  def fixture_text(path)
    record = JSON.parse(File.read(path).lines.first)
    record.dig("response", "content").select { |block| block["type"] == "text" }.map { |block| block["text"] }.join
  end
end
