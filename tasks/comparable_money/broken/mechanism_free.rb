class Money
  attr_reader :cents

  def initialize(cents)
    @cents = cents
  end

  def <=>(other)
    cents <=> other.cents
  end

  def <(other)
    cents < other.cents
  end

  def ==(other)
    cents == other.cents
  end

  def clamp(min, max)
    return min if cents < min.cents
    return max if cents > max.cents

    self
  end
end
