class String
  def hollow?
    strip.empty?
  end
end

class HollowChecker
  def self.hollow?(str)
    str.hollow?
  end
end
