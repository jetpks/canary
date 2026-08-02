module HollowCheck
  refine String do
    def hollow?
      strip.empty?
    end
  end
end

class HollowChecker
  # BUG: forgot `using HollowCheck` - the refinement is defined but never
  # activated in this scope, so String#hollow? isn't callable here at all.

  def self.hollow?(str)
    str.hollow?
  end
end
