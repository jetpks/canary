module Normalizer
  def self.squash(text)
    text.downcase!
    text.gsub!(/\s+/, " ")
    text.strip!
    text
  end
end
