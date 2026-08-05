class ExpenseTracker
  class NearestCent
    def round(amount)
      amount.round(2)
    end
  end

  def initialize(rounding: NearestCent.new)
    @rounding = rounding
    @records = []
  end

  def record(amount)
    @records << @rounding.round(amount)
    self
  end

  def total
    @records.sum
  end
end
