class Weight
  include Comparable

  attr_reader :amount, :unit

  def initialize(amount, unit)
    @amount = amount
    @unit = unit
  end

  def <=>(other)
    return nil unless other.is_a?(Weight)

    amount <=> other.amount
  end
end
