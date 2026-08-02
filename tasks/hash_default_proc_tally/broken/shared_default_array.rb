class Tally
  def self.group_by_parity(numbers)
    result = Hash.new([])
    numbers.each { |n| result[n.even? ? :even : :odd] << n }
    result
  end
end
