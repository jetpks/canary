module Normalizer
  def self.squash(text)
    copy = text.frozen? ? text.dup : text
    copy.downcase!
    copy.gsub!(/\s+/, " ")
    copy.strip!
    copy
  end
end
