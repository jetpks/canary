class OpenRecordGraderTest < Minitest::Test
  def test_reads_attributes_set_at_construction
    record = OpenRecord.new(name: "Ada", age: 36)
    assert_equal "Ada", record.name
    assert_equal 36, record.age
  end

  def test_writes_a_new_attribute_dynamically
    record = OpenRecord.new(name: "Ada")
    record.age = 37
    assert_equal 37, record.age
  end

  def test_responds_to_known_and_settable_attributes
    record = OpenRecord.new(name: "Ada")
    assert record.respond_to?(:name)
    assert record.respond_to?(:age=)
  end

  def test_raises_on_a_truly_unknown_getter
    record = OpenRecord.new(name: "Ada")
    assert_raises(NoMethodError) { record.unknown_field }
  end
end
