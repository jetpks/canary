class Reading
  attr_reader :whole, :fraction

  def initialize(whole, fraction)
    @whole = whole
    @fraction = fraction
  end

  def exact
    (whole + fraction).to_f
  end

  def ==(other)
    other.is_a?(Reading) && exact == other.exact
  end
end
