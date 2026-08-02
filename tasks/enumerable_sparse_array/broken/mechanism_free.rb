class SparseArray
  def initialize
    @store = {}
  end

  def []=(index, value)
    @store[index] = value
  end

  def to_a
    @store.keys.sort.map { |k| @store[k] }
  end

  def sum
    to_a.sum
  end

  def select(&block)
    to_a.select(&block)
  end

  def count
    @store.size
  end
end
