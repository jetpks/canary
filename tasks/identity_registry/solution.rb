class Registry
  def initialize
    @items = []
  end

  def register(obj)
    @items << obj unless registered?(obj)
    self
  end

  def registered?(obj)
    @items.any? { |item| item.equal?(obj) }
  end

  def size
    @items.size
  end

  def to_a
    @items.dup
  end
end
