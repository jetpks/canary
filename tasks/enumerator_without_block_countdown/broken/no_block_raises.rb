class Steps
  def initialize(from)
    @from = from
  end

  def each
    @from.downto(1) { |n| yield n }
    self
  end
end
