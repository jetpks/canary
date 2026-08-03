class TruncatorGraderTest < Minitest::Test
  def test_returns_short_strings_unchanged
    assert_equal "hi", Truncator.truncate("hi", 10)
  end

  def test_truncates_a_long_ascii_string_and_appends_an_ellipsis_capped_at_the_limit
    result = Truncator.truncate("abcdefghij", 5)
    assert_equal "abcd…", result
    assert_equal 5, result.length
  end

  def test_counts_multi_byte_characters_as_single_characters_when_truncating
    result = Truncator.truncate("café bar", 5)
    assert_equal "café…", result
    assert_equal 5, result.length
  end

  def test_never_splits_a_multi_byte_character_in_half
    result = Truncator.truncate("🎉🎉🎉🎉🎉", 3)
    assert result.valid_encoding?
    assert_equal "🎉🎉…", result
  end

  def test_does_not_truncate_a_string_that_is_short_in_characters_but_long_in_bytes
    assert_equal "café", Truncator.truncate("café", 4)
  end
end
