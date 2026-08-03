class Band
  def initialize(min, max)
    @min = min
    @max = max
  end

  def ===(number)
    number >= @min && number <= @max
  end
end
