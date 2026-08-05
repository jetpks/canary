class KeyStore
  def initialize
    @data = {}
  end

  def store(key, value)
    @data[key] = value
  end

  def fetch(key)
    return @data[key] if stored?(key)
    return yield if block_given?

    nil
  end

  protected

  def stored?(key)
    @data.key?(key)
  end
end

class TallyingKeyStore < KeyStore
  def initialize
    super
    @hits = 0
    @misses = 0
  end

  attr_reader :hits, :misses

  def fetch(key)
    if stored?(key)
      @hits += 1
      super
    else
      @misses += 1
      super { yield }
    end
  end
end
