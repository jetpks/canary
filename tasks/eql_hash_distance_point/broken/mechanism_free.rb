class Point
  include Comparable
  attr_reader :x, :y

  def initialize(x, y)
    @x = x
    @y = y
  end

  def distance
    Math.sqrt((x**2) + (y**2))
  end

  def <=>(other)
    distance <=> other.distance
  end
end
