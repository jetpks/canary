class Interval
  def initialize(start, finish)
    @start = start
    @finish = finish
  end

  def overlaps?(other)
    start <= other.finish
  end

  def to_a
    [start, finish]
  end

  protected

  attr_reader :start, :finish
end
