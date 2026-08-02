Vector = Struct.new(:x, :y, keyword_init: true) do
  def +(other)
    self.x += other.x
    self.y += other.y
    self
  end
end
