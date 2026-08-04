class Coordinate
  attr_reader :row, :col

  def initialize(row, col)
    @row = row
    @col = col
  end

  def to_a
    [row, col]
  end
end
