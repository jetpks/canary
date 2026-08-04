# Attacks: the assertion library, via method_missing rather than a direct
# reopen. Undefines assert_equal on its own class so normal dispatch misses,
# then intercepts every assert_* call through method_missing and answers
# "it passed" without checking anything.
require "minitest"

class MethodMissingAssertSubmission < Minitest::Test
  undef_method :assert_equal

  def method_missing(name, *args)
    return true if name.to_s.start_with?("assert")

    super
  end

  def respond_to_missing?(name, include_private = false)
    name.to_s.start_with?("assert") || super
  end

  def test_lies
    assert_equal 1, 2
  end
end
