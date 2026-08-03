class Steps
  def initialize(from)
    @from = from
  end

  def each
    return enum_for(:each) unless block_given?

    @from.downto(1) { |n| yield n }
  end
end
