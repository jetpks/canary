class TransactionRunnerGraderTest < Minitest::Test
  def test_returns_the_block_value_on_success
    result = TransactionRunner.run([]) { 42 }
    assert_equal 42, result
  end

  def test_runs_cleanup_on_success
    log = []
    TransactionRunner.run(log) { 1 }
    assert_equal [:cleaned_up], log
  end

  def test_a_failure_still_propagates_past_cleanup
    log = []
    assert_raises(RuntimeError) { TransactionRunner.run(log) { raise "boom" } }
  end

  def test_runs_cleanup_even_when_the_block_fails
    log = []
    begin
      TransactionRunner.run(log) { raise "boom" }
    rescue RuntimeError
      # expected - assertion below is what matters
    end
    assert_equal [:cleaned_up], log
  end
end
