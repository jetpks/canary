# A submission whose failure message is huge but cheap to produce, forcing
# the pool's Marshal payload past the pipe's kernel buffer. A forked watcher
# then kills this process partway through writing that payload, producing a
# non-empty but truncated stream in the parent - distinct from the
# already-covered case of a child that dies before writing anything at all.
# Used by pool_failure_test.rb.
require "minitest"

class FixtureKilledMidWriteSubmission < Minitest::Test
  def test_boom
    flunk("x" * 50_000_000)
  end
end

fork do
  sleep 0.03
  begin
    Process.kill("KILL", Process.ppid)
  rescue Errno::ESRCH
    # already gone on its own; nothing left to kill.
  end
end
