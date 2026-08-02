module WithdrawalAudit
  def withdraw(amount)
    log << "attempting withdrawal of #{amount}"
    log << "withdrawal of #{amount} succeeded, balance now #{balance}"
    amount
  end

  def log
    @log ||= []
  end
end

class AuditedAccount
  prepend WithdrawalAudit

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
