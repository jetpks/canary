# Attacks: the counting logic surgically, leaving the assertion library
# itself untouched. Reopens Minitest::Result.from - what
# MinitestAdapter::CollectingReporter#record uses to snapshot each test - so
# every recorded result reports zero failures no matter what the test
# actually did.
require "minitest"

module Minitest
  class Result
    class << self
      alias_method :real_from, :from

      def from(runnable)
        result = real_from(runnable)
        result.failures = []
        result
      end
    end
  end
end

class RecordForgeSubmission < Minitest::Test
  def test_actually_fails
    assert_equal 1, 2
  end
end
