class AttrParser
  PATTERN = /(?<key>\w+)="(?<value>[^ "]*?)"/

  def self.parse(line)
    result = {}
    line.scan(PATTERN) { result[Regexp.last_match(:key).to_sym] = Regexp.last_match(:value) }
    result
  end
end
