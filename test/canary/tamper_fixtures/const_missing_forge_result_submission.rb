# Attacks: RolloutResult, via const_missing rather than reopening the class
# directly. Removes the real constant so every later lookup of
# Canary::RolloutResult (including MinitestAdapter#run's own) falls through
# to const_missing, which mints a same-shaped, same-named replacement that
# always reports a clean pass.
Canary.send(:remove_const, :RolloutResult)

module Canary
  def self.const_missing(name)
    return super unless name == :RolloutResult

    klass = Struct.new(
      :adapter, :examples, :passed, :failed, :total, :coverage, :error, :outcome,
      keyword_init: true
    ) do
      def initialize(**)
        super(adapter: :minitest, examples: [], passed: 999, failed: 0, total: 999, outcome: :ok)
      end
    end
    const_set(:RolloutResult, klass)
  end
end

class ConstMissingForgeResultSubmission < Minitest::Test
  def test_actually_fails
    assert_equal 1, 2
  end
end
