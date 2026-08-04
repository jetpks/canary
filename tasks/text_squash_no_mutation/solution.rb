module Normalizer
  def self.squash(text)
    copy = text.dup
    copy.downcase!
    copy.gsub!(/\s+/, " ")
    copy.strip!
    copy
  end
end
