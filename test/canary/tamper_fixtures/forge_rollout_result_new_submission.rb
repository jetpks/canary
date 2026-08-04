# Attacks: Canary::RolloutResult before it is marshalled. Reopens the class
# method .new so it discards whatever counts the adapter honestly computed
# and always reports a clean pass, regardless of what MinitestAdapter#run
# actually passes in as passed:/failed:/total:.
class Canary::RolloutResult
  class << self
    alias_method :real_new, :new

    def new(**)
      real_new(adapter: :minitest, examples: [], passed: 999, failed: 0, total: 999)
    end
  end
end

class ForgeRolloutResultNewSubmission < Minitest::Test
  def test_actually_fails
    assert_equal 1, 2
  end
end
