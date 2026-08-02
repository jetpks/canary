module Shapes
  PI = 3.0

  class Circle
    def initialize(radius)
      @radius = radius
    end

    def area
      Math::PI * @radius**2
    end

    def circumference
      Math::PI * @radius
    end
  end
end
