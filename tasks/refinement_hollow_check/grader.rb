class HollowCheckerGraderTest < Minitest::Test
  def test_hollow_for_an_empty_string
    assert HollowChecker.hollow?("")
  end

  def test_hollow_for_whitespace_only
    assert HollowChecker.hollow?("   ")
  end

  def test_not_hollow_for_content
    refute HollowChecker.hollow?("hello")
  end

  def test_the_refinement_does_not_leak_outside_its_using_scope
    refute "".respond_to?(:hollow?)
  end
end
