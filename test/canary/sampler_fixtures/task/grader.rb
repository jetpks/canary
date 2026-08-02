class WidgetGraderTest < Minitest::Test
  def test_wrap_returns_widget
    assert_equal Widget, Widget.wrap
  end
end
