class StockCount
  attr_reader :count

  def initialize(count)
    @count = count
  end

  def -(other)
    if other.is_a?(StockCount)
      (count - other.count).to_f
    else
      count - other
    end
  end

  def ==(other)
    other.is_a?(StockCount) && count == other.count
  end
end
