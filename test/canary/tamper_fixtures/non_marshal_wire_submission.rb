# Attacks: the wire itself, same as pipe_hijack_submission.rb, but cheaper -
# no forged Marshal.dump required at all. Writing plain non-Marshal bytes
# onto the relay-owned pipe the worker still holds open (found the same way:
# ObjectSpace can see it even though this process only inherited it by fork,
# not by reference) puts unparseable data ahead of the real result on the
# wire. Marshal.load never gets past those bytes to the honest object that
# follows, so this is really a test of Pool#marshalled_result's own error
# handling, not of the forgery itself.
writer = ObjectSpace.each_object(IO).find do |io|
  !io.closed? && io.stat.pipe? && ![$stdin, $stdout, $stderr].include?(io)
rescue IOError
  false
end

writer&.write("not marshal data at all")

require "minitest"

class NonMarshalWireSubmission < Minitest::Test
  def test_actually_fails
    assert_equal 1, 2
  end
end
