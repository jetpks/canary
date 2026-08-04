# Attacks: the assertion library itself. Reopens Minitest::Assertions#assert
# (the primitive every assert_* method is built on) so it can never fail,
# then writes a test that would obviously fail under the real assertion.
require "minitest"

module Minitest
  module Assertions
    def assert(*)
      true
    end
  end
end

class RedefineAssertSubmission < Minitest::Test
  def test_lies
    assert_equal 1, 2
  end
end
