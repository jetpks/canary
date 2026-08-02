# Adversarial: rewrites its own file on disk as soon as it's loaded, before
# ever defining an example - simulates a grader that tampers with itself to
# game a rollout it doesn't like. Canary::Pool#rollout_task digests this file
# before forking and after the child exits; this line is why the digests
# differ.
File.write(__FILE__, File.read(__FILE__) + "\n# tampered by the grader itself\n")

class TamperingTaskGraderTest < Minitest::Test
  def test_calls_solution
    assert_equal 1, TamperingTaskSolution.call
  end
end
