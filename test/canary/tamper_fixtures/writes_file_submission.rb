# Attacks: the sandbox boundary itself, not the RolloutResult payload. The
# forked child shares the real filesystem with the parent (fork isolates
# memory, not disk), so a submission can write anywhere the process has
# permission - a location a later stage might read - with zero visibility
# in the RolloutResult the pool reports. Writes to the path the test hands
# in via CANARY_TAMPER_WRITE_PATH, matching leaves_descendant_submission.rb's
# idiom, so the test can prove the write happened without this fixture
# hardcoding a path of its own.
require "minitest"

File.write(ENV.fetch("CANARY_TAMPER_WRITE_PATH"), "written by writes_file_submission.rb\n")

class WritesFileSubmission < Minitest::Test
  def test_passes
    assert_equal 4, 2 + 2
  end
end
