class Reading
  attr_reader :whole, :fraction

  def initialize(whole, fraction)
    @whole = whole
    @fraction = fraction
  end

  def exact
    Rational(whole, 1)
  end

  def ==(other)
    other.is_a?(Reading) && exact == other.exact
  end
end
