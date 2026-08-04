class Attributes
  def initialize(values = {})
    @values = values.dup
  end

  def to_h
    @values.dup
  end

  def ==(other)
    other.respond_to?(:to_h) && to_h == other.to_h
  end
end
