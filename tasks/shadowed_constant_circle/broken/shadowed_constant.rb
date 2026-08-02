module Shapes
  PI = 3.0

  class Circle
    def initialize(radius)
      @radius = radius
    end

    def area
      PI * @radius**2
    end

    def circumference
      2 * PI * @radius
    end
  end
end
