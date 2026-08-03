class Ledger
  def initialize(entries = [])
    @entries = entries.dup
  end

  def add(entry)
    @entries << entry
    self
  end

  def entries
    @entries
  end
end
