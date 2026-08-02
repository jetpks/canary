# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/target"

module Target
  class CalculatorTest < Minitest::Test
    cover "Target::Calculator*" if respond_to?(:cover)

    def setup
      @calc = Calculator.new
    end

    def test_add
      assert_equal 5, @calc.add(2, 3)
    end

    def test_subtract
      assert_equal(-1, @calc.subtract(2, 3))
    end

    def test_multiply
      assert_equal 6, @calc.multiply(2, 3)
    end

    def test_divide
      assert_equal 2, @calc.divide(6, 3)
    end

    def test_divide_by_zero_raises
      assert_raises(ZeroDivisionError) { @calc.divide(1, 0) }
    end

    def test_clamp_within_range
      assert_equal 5, @calc.clamp(5, 0, 10)
    end

    def test_clamp_below_min
      assert_equal 0, @calc.clamp(-5, 0, 10)
    end

    def test_clamp_above_max
      assert_equal 10, @calc.clamp(15, 0, 10)
    end

    def test_even
      assert @calc.even?(4)
      refute @calc.even?(3)
    end
  end

  class StringUtilsTest < Minitest::Test
    cover "Target::StringUtils*" if respond_to?(:cover)

    def setup
      @utils = StringUtils.new
    end

    def test_blank_nil
      assert @utils.blank?(nil)
    end

    def test_blank_whitespace
      assert @utils.blank?("   ")
    end

    def test_blank_false
      refute @utils.blank?("hi")
    end

    def test_truncate_short
      assert_equal "hi", @utils.truncate("hi", 5)
    end

    def test_truncate_long
      assert_equal "hel...", @utils.truncate("hello world", 3)
    end

    def test_shout
      assert_equal "HI!", @utils.shout("hi")
    end
  end
end
