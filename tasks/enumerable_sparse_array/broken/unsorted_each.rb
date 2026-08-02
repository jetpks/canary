class SparseArray
  include Enumerable

  def initialize
    @store = {}
  end

  def []=(index, value)
    @store[index] = value
  end

  def each
    return enum_for(:each) unless block_given?

    @store.each_value { |value| yield value }
  end
end
