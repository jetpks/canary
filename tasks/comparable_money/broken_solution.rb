class Money
  include Comparable
  attr_reader :cents

  def initialize(cents)
    @cents = cents
  end

  def <=>(other)
    cents.to_s <=> other.cents.to_s
  end
end
