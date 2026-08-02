class Memoizer
  def self.wrap(&computation)
    computed = false
    value = nil
    lambda do |*args|
      unless computed
        value = computation.call(*args)
        computed = true
      end
      value
    end
  end
end
