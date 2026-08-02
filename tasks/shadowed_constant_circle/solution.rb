module Shapes
  # A deliberately naive approximation kept around for a coarse display
  # format elsewhere in Shapes - real geometry must reach past it to
  # Math::PI explicitly, since a bare PI inside Circle resolves lexically
  # to this constant first.
  PI = 3.0

  class Circle
    def initialize(radius)
      @radius = radius
    end

    def area
      Math::PI * @radius**2
    end

    def circumference
      2 * Math::PI * @radius
    end
  end
end
