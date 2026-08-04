class Tally
  def self.group_by(items)
    result = Hash.new { |hash, key| hash[key] = [] }
    items.each { |item| result[item] << yield(item) }
    result
  end
end
