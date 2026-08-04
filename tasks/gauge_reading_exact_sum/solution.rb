class Reading
  attr_reader :whole, :fraction

  def initialize(whole, fraction)
    @whole = whole
    @fraction = fraction
  end

  def exact
    whole + fraction
  end

  def ==(other)
    other.is_a?(Reading) && exact == other.exact
  end
end
