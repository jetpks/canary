class AuditedAccountGraderTest < Minitest::Test
  def test_withdrawal_reduces_the_balance
    account = AuditedAccount.new(100)
    account.withdraw(30)
    assert_equal 70, account.balance
  end

  def test_withdrawal_is_logged_before_and_after
    account = AuditedAccount.new(100)
    account.withdraw(30)
    assert_equal 2, account.log.size
    assert_match(/attempting withdrawal of 30/, account.log.first)
  end

  def test_the_after_log_line_names_the_amount_and_the_resulting_balance
    account = AuditedAccount.new(100)
    account.withdraw(30)
    assert_match(/30/, account.log.last)
    assert_match(/70/, account.log.last)
  end

  def test_an_overdraft_still_raises
    account = AuditedAccount.new(50)
    assert_raises(ArgumentError) { account.withdraw(100) }
  end

  def test_an_overdraft_logs_the_attempt_but_never_a_success
    account = AuditedAccount.new(50)
    assert_raises(ArgumentError) { account.withdraw(100) }
    assert_equal 1, account.log.size
    assert_match(/attempting withdrawal of 100/, account.log.first)
  end

  def test_two_successive_withdrawals_both_log_and_both_reduce_the_balance
    account = AuditedAccount.new(100)
    account.withdraw(30)
    account.withdraw(20)
    assert_equal 50, account.balance
    assert_equal 4, account.log.size
  end
end
