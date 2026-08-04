# Attacks the opposite direction from every other fixture here: not "make a
# failure look like a pass" but "make a real pass unreportable". Coverage's
# bare .result stops measurement as a side effect. run_in_child calls it a
# second time after the adapter returns (pool.rb:137); once this submission
# calls it first, that second call raises RuntimeError ("coverage
# measurement is not enabled"), which is a StandardError, so run_in_child's
# own rescue turns an honestly-passing rollout into outcome: :error - a
# correct result destroyed, not a false one forged. (A milder
# Coverage.result(stop: false, clear: false) call was tried first and does
# NOT trigger this - the later call still succeeds untouched.)
Coverage.result

class CoverageCorruptionSubmission < Minitest::Test
  def test_actually_passes
    assert_equal 4, 2 + 2
  end
end
