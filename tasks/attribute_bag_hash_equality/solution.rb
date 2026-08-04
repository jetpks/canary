class Attributes
  def initialize(values = {})
    @values = values.dup
  end

  def to_h
    @values.dup
  end

  def ==(other)
    other.is_a?(Hash) && to_h == other.to_h
  end
end
