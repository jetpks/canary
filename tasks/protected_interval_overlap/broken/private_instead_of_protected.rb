class Interval
  def initialize(start, finish)
    @start = start
    @finish = finish
  end

  def overlaps?(other)
    start <= other.finish && finish >= other.start
  end

  def to_a
    [start, finish]
  end

  private

  attr_reader :start, :finish
end
