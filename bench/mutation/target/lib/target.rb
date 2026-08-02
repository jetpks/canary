# frozen_string_literal: true

# Small gem-shaped target used to compare mutation-testing tools
# (mutant vs mutineer) under identical conditions. See bench/mutation/compare.rb.
module Target
  class Calculator
    def add(a, b)
      a + b
    end

    def subtract(a, b)
      a - b
    end

    def multiply(a, b)
      a * b
    end

    def divide(a, b)
      raise ZeroDivisionError, "divided by 0" if b.zero?

      a / b
    end

    def clamp(value, min, max)
      return min if value < min
      return max if value > max

      value
    end

    def even?(value)
      value % 2 == 0
    end
  end

  class StringUtils
    def blank?(str)
      str.nil? || str.strip.empty?
    end

    def truncate(str, length)
      return str if str.length <= length

      "#{str[0...length]}..."
    end

    def shout(str)
      str.upcase + "!"
    end
  end
end
