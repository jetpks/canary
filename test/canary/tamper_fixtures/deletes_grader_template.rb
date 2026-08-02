# Copied fresh into a Tempfile per test run (see tamper_test.rb) rather than
# used directly, so deletes_grader_submission.rb has a real, disposable
# grader file to delete without ever touching a checked-in fixture.
require "minitest"

class DeletesGraderGraderTest < Minitest::Test
  def test_dummy
    assert true
  end
end
