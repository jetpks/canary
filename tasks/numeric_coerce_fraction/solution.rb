class Fraction
  attr_reader :numerator, :denominator

  def initialize(numerator, denominator)
    @numerator = numerator
    @denominator = denominator
  end

  def +(other)
    other = Fraction.new(other, 1) unless other.is_a?(Fraction)
    Fraction.new((numerator * other.denominator) + (other.numerator * denominator), denominator * other.denominator)
  end

  def coerce(other)
    [Fraction.new(other, 1), self]
  end

  def ==(other)
    other.is_a?(Fraction) && numerator == other.numerator && denominator == other.denominator
  end
end
