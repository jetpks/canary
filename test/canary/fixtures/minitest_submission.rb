require "minitest"

class FixtureMinitestSubmission < Minitest::Test
  def target
    2 + 2
  end

  def test_addition_passes
    assert_equal 4, target
  end

  def test_addition_fails
    assert_equal 5, target
  end
end
