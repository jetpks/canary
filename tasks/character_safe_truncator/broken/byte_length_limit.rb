class Truncator
  ELLIPSIS = "…"

  def self.truncate(str, limit)
    return str if str.bytesize <= limit

    "#{str.byteslice(0, limit - ELLIPSIS.bytesize)}#{ELLIPSIS}"
  end
end
