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

  def test_an_overdraft_still_raises
    account = AuditedAccount.new(50)
    assert_raises(ArgumentError) { account.withdraw(100) }
  end

  def test_the_wrapping_module_sits_above_the_class_in_the_ancestor_chain
    assert_equal WithdrawalAudit, AuditedAccount.ancestors[0]
  end
end
