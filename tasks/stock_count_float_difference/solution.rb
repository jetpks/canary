class StockCount
  attr_reader :count

  def initialize(count)
    @count = count
  end

  def -(other)
    difference = other.is_a?(StockCount) ? count - other.count : count - other
    difference.to_f
  end

  def ==(other)
    other.is_a?(StockCount) && count == other.count
  end
end
