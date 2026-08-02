class Tally
  def self.group_by_parity(numbers)
    result = Hash.new { |hash, key| hash[key] = [] }
    numbers.each { |n| result[n.odd? ? :even : :odd] << n }
    result
  end
end
