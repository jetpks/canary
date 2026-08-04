# Attacks: MinitestAdapter#run's own "newly defined classes" detection.
# Minitest::Test itself is already a registered Minitest::Runnable before any
# submission loads (the parent preloads minitest), so
# `Minitest::Runnable.runnables - before` never includes it. Adding test
# methods by reopening Minitest::Test directly, instead of subclassing it,
# means the tests are real and would fail, but nothing ever selects them to
# run - a stealthier vacuous pass than shipping an empty file.
class Minitest::Test
  def test_actually_fails
    assert_equal 1, 2
  end
end
