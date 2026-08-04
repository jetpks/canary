class Attributes
  def initialize(values = {})
    @values = values.dup
  end

  def to_h
    @values.dup
  end

  def ==(other)
    to_h == other.to_h
  end
end
