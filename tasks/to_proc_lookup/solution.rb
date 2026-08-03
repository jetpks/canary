class Lookup
  def initialize(table)
    @table = table
  end

  def call(key)
    @table.fetch(key)
  end

  def to_proc
    method(:call).to_proc
  end
end
