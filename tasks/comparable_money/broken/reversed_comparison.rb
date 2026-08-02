class Money
  include Comparable
  attr_reader :cents

  def initialize(cents)
    @cents = cents
  end

  def <=>(other)
    other.cents <=> cents
  end
end
