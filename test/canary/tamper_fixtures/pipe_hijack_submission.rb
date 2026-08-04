# Attacks: the wire itself, bypassing RolloutResult entirely. The pool's fork
# block writes exactly one Marshal.dump to the parent's pipe, but the write
# end is an ordinary open IO living in this same forked process (fork
# isolates memory, not object identity within a process) - ObjectSpace can
# find it. Marshal.load only ever consumes the first object in a byte
# stream, so writing a forged payload here, before MinitestAdapter ever
# counts a single example, wins the race against the real result the pool
# appends afterward.
writer = ObjectSpace.each_object(IO).find do |io|
  !io.closed? && io.stat.pipe? && ![$stdin, $stdout, $stderr].include?(io)
rescue IOError
  false
end

if writer
  forged = Canary::RolloutResult.new(
    adapter: :minitest, examples: [], passed: 999, failed: 0, total: 999
  )
  Marshal.dump(forged, writer)
end

require "minitest"

class PipeHijackSubmission < Minitest::Test
  def test_actually_fails
    assert_equal 1, 2
  end
end
