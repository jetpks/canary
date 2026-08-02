class Tally
  def self.group_by(items)
    result = Hash.new([])
    items.each { |item| result[yield(item)] << item }
    result
  end
end
