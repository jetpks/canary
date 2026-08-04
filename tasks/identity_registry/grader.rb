class RegistryGraderTest < Minitest::Test
  def test_register_returns_the_registry_itself
    registry = Registry.new
    assert_same registry, registry.register("a")
  end

  def test_size_and_to_a_reflect_registration_order
    registry = Registry.new
    registry.register(:a)
    registry.register(:b)
    assert_equal 2, registry.size
    assert_equal [:a, :b], registry.to_a
  end

  def test_registering_the_same_object_twice_does_not_grow_the_registry
    registry = Registry.new
    tag = "shared"
    registry.register(tag)
    registry.register(tag)
    assert_equal 1, registry.size
  end

  def test_registering_a_different_but_equal_valued_object_adds_a_distinct_member
    registry = Registry.new
    first = "duplicate"
    second = "duplicate".dup
    registry.register(first)
    registry.register(second)
    assert_equal 2, registry.size
    assert_equal [first, second], registry.to_a
  end

  def test_registered_predicate_is_true_only_for_the_same_object
    registry = Registry.new
    first = "duplicate"
    second = "duplicate".dup
    registry.register(first)
    assert registry.registered?(first)
    refute registry.registered?(second)
  end
end
