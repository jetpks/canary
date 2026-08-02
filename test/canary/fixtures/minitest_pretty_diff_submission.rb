require "minitest"

class FixtureMinitestPrettyDiffSubmission < Minitest::Test
  make_my_diffs_pretty!

  def test_addition_passes
    assert_equal 4, 2 + 2
  end
end
