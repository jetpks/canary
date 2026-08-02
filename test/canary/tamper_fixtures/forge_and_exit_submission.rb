# Attacks: forges a single object then exits before the honest write ever
# runs. Unlike pipe_hijack_submission.rb - which leaves the real Minitest
# run to follow, so the wire ends up carrying the forged object *and* the
# honest one, which Pool#marshalled_result already catches via its io.eof?
# check - this fixture calls exit! immediately after its forged write. The
# wire it produces carries exactly one object and the process it came from
# exited status 0, same as an honest result: byte-for-byte indistinguishable
# from the real thing from the wire alone. See tamper_test.rb for why this
# stays a documented skip rather than a closed vector.
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
  exit!(0)
end

require "minitest"

class ForgeAndExitSubmission < Minitest::Test
  def test_actually_fails
    assert_equal 1, 2
  end
end
