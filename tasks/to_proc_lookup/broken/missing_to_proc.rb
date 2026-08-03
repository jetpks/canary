class Lookup
  def initialize(table)
    @table = table
  end

  def call(key)
    @table.fetch(key)
  end
end
