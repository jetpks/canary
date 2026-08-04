class Cache
  Entry = Struct.new(:payload, :stale) do
    def stale?
      stale
    end
  end

  def initialize(packer: nil)
    @packer = packer
    @raw = {}
  end

  def write(key, payload, stale: false)
    entry = Entry.new(payload, stale)
    @raw[key] = @packer ? @packer.dump(entry) : entry
  end

  def read(key)
    entry = @raw[key]
    entry&.payload
  end

  def sweep
    @raw.keys.each do |key|
      entry = unpack(@raw[key])
      @raw.delete(key) if entry&.stale?
    end
  end

  private

  def unpack(raw)
    return nil if raw.nil?

    @packer ? @packer.load(raw) : raw
  end
end
