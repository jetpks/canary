class Registry
  def initialize
    @items = []
  end

  def register(obj)
    @items << obj unless @items.include?(obj)
    self
  end

  def registered?(obj)
    @items.include?(obj)
  end

  def size
    @items.size
  end

  def to_a
    @items.dup
  end
end
