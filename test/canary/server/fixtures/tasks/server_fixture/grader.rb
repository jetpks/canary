class CanaryServerFixtureAdderTest < Minitest::Test
  def test_adds_two_numbers
    assert_equal 4, CanaryServerFixture::Adder.call(2, 2)
  end
end
