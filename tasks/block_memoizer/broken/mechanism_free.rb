class Memoizer
  def self.wrap(&computation)
    value = nil
    lambda do |*args|
      value ||= computation.call(*args)
    end
  end
end
