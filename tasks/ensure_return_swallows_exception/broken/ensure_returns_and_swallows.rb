class TransactionRunner
  def self.run(log)
    yield
  ensure
    log << :cleaned_up
    return :cleaned
  end
end
