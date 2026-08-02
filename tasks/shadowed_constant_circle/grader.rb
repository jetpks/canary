class CircleGraderTest < Minitest::Test
  def test_area_uses_the_real_value_of_pi_not_the_shadowed_local_constant
    assert_in_delta Math::PI * 4, Shapes::Circle.new(2).area, 0.0001
  end

  def test_circumference_uses_the_real_value_of_pi_and_the_full_diameter
    assert_in_delta 2 * Math::PI * 2, Shapes::Circle.new(2).circumference, 0.0001
  end

  def test_area_is_zero_for_a_zero_radius
    assert_equal 0.0, Shapes::Circle.new(0).area
  end

  def test_circumference_scales_linearly_with_radius
    circle = Shapes::Circle.new(2)
    doubled = Shapes::Circle.new(4)
    assert_in_delta doubled.circumference, circle.circumference * 2, 0.0001
  end
end
