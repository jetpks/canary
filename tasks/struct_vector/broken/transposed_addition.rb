Vector = Struct.new(:x, :y, keyword_init: true) do
  def +(other)
    Vector.new(x: x - other.x, y: y - other.y)
  end
end
