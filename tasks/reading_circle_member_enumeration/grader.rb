class ArrayDirectory
  def initialize(names)
    @names = names
  end

  def members
    @names
  end
end

class EachOnlyMembers
  def initialize(names)
    @names = names
  end

  def each
    return enum_for(:each) unless block_given?

    @names.each { |name| yield name }
  end
end

class EachOnlyDirectory
  def initialize(names)
    @names = names
  end

  def members
    EachOnlyMembers.new(@names)
  end
end

class ReadingCircleGraderTest < Minitest::Test
  def test_roster_size_with_an_array_backed_directory
    circle = ReadingCircle.new(ArrayDirectory.new(["Ada", "Grace"]))
    assert_equal 2, circle.roster_size
  end

  def test_greeting_with_an_array_backed_directory
    circle = ReadingCircle.new(ArrayDirectory.new(["Ada", "Grace"]))
    assert_equal "Ada, Grace", circle.greeting
  end

  def test_roster_size_with_an_each_only_directory
    circle = ReadingCircle.new(EachOnlyDirectory.new(["Ada", "Grace", "Marie"]))
    assert_equal 3, circle.roster_size
  end

  def test_greeting_with_an_each_only_directory
    circle = ReadingCircle.new(EachOnlyDirectory.new(["Ada", "Grace", "Marie"]))
    assert_equal "Ada, Grace, Marie", circle.greeting
  end

  def test_reflects_a_fresh_enumeration_on_every_call
    circle = ReadingCircle.new(EachOnlyDirectory.new(["Ada"]))
    assert_equal 1, circle.roster_size
    assert_equal "Ada", circle.greeting
    assert_equal 1, circle.roster_size
  end
end
