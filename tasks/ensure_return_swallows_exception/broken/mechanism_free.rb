class TransactionRunner
  def self.run(log)
    result = yield
    log << :cleaned_up
    result
  end
end
