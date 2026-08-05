class TemperatureReport
  class Celsius
    def convert(celsius_degrees)
      celsius_degrees
    end

    def label
      "C"
    end
  end

  def initialize(scale: Celsius.new)
    @scale = scale
  end

  def describe(celsius_degrees)
    "#{@scale.label}#{@scale.convert(celsius_degrees)}"
  end
end
