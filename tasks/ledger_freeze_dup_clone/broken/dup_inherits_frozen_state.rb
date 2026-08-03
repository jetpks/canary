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

  def freeze
    @entries.freeze
    super
  end

  private

  def initialize_copy(other)
    super
    @entries = other.instance_variable_get(:@entries).dup
    freeze if other.frozen?
  end
end
