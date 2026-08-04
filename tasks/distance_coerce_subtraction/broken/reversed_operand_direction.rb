class Distance
  attr_reader :meters

  def initialize(meters)
    @meters = meters
  end

  def -(other)
    other = Distance.new(other) unless other.is_a?(Distance)
    Distance.new(other.meters - meters)
  end

  def coerce(other)
    [Distance.new(other), self]
  end

  def ==(other)
    other.is_a?(Distance) && meters == other.meters
  end
end
