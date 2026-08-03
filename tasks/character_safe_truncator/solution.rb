class Truncator
  ELLIPSIS = "…"

  def self.truncate(str, limit)
    return str if str.length <= limit

    "#{str[0, limit - ELLIPSIS.length]}#{ELLIPSIS}"
  end
end
