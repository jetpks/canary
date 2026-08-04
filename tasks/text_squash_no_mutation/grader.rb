class NormalizerGraderTest < Minitest::Test
  def test_collapses_whitespace_and_downcases
    assert_equal "hello world", Normalizer.squash("  Hello   World  ")
  end

  def test_does_not_mutate_an_unfrozen_argument
    text = String.new("  Hello   World  ")
    original = text.dup
    Normalizer.squash(text)
    assert_equal original, text
  end

  def test_does_not_raise_or_mutate_a_frozen_argument
    text = "  Hello   World  ".freeze
    result = Normalizer.squash(text)
    assert_equal "hello world", result
    assert_equal "  Hello   World  ", text
  end

  def test_returns_a_new_string_object_not_the_same_object
    text = "already normal"
    refute_same text, Normalizer.squash(text)
  end
end
