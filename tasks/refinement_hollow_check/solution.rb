module HollowCheck
  refine String do
    def hollow?
      strip.empty?
    end
  end
end

class HollowChecker
  using HollowCheck

  def self.hollow?(str)
    str.hollow?
  end
end
