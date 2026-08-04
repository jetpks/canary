class Truncator
  def self.truncate(str, limit)
    str.byteslice(0, limit)
  end
end
