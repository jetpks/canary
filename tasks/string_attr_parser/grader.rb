class AttrParserGraderTest < Minitest::Test
  def test_parses_a_single_key_value_pair
    assert_equal({ name: "ada" }, AttrParser.parse('name="ada"'))
  end

  def test_parses_multiple_pairs_without_greedily_crossing_quotes
    result = AttrParser.parse('name="ada" role="admin"')
    assert_equal({ name: "ada", role: "admin" }, result)
  end

  def test_handles_a_value_containing_spaces
    assert_equal({ msg: "hello world" }, AttrParser.parse('msg="hello world"'))
  end

  def test_returns_an_empty_hash_for_a_line_with_no_matches
    assert_equal({}, AttrParser.parse("no attrs here"))
  end
end
