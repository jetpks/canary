module WithdrawalAudit
  def withdraw(amount)
    log << "attempting withdrawal of #{amount}"
    result = super
    log << "withdrawal of #{amount} succeeded, balance now #{balance}"
    result
  end

  def log
    @log ||= []
  end
end

class AuditedAccount
  include WithdrawalAudit

  attr_reader :balance

  def initialize(balance)
    @balance = balance
  end

  def withdraw(amount)
    raise ArgumentError, "insufficient funds" if amount > balance

    @balance -= amount
    balance
  end
end
