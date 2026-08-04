class Tally
  def self.group_by(items)
    result = Hash.new { |hash, key| hash[key] = [] }
    items.each { |item| result[yield(item)] << item }
    result
  end
end
