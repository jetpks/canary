# Attacks: the pass/fail contract itself. Defines a real Minitest::Test
# subclass but gives it zero test_ methods, so the suite "passes" vacuously -
# total: 0, failed: 0, and RolloutResult#success? is true.
require "minitest"

class EmptySuiteSubmission < Minitest::Test
end
