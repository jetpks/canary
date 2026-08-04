class CacheGraderTest < Minitest::Test
  def test_round_trips_a_written_value_without_a_packer
    cache = Cache.new
    cache.write(:a, "hello")
    assert_equal "hello", cache.read(:a)
  end

  def test_sweep_removes_stale_entries_and_keeps_fresh_ones_without_a_packer
    cache = Cache.new
    cache.write(:a, "stale value", stale: true)
    cache.write(:b, "fresh value")
    cache.sweep
    assert_nil cache.read(:a)
    assert_equal "fresh value", cache.read(:b)
  end

  def test_round_trips_a_written_value_with_a_marshal_packer
    cache = Cache.new(packer: Marshal)
    cache.write(:a, "hello")
    assert_equal "hello", cache.read(:a)
  end

  def test_sweep_removes_stale_entries_and_keeps_fresh_ones_with_a_marshal_packer
    cache = Cache.new(packer: Marshal)
    cache.write(:a, "stale value", stale: true)
    cache.write(:b, "fresh value")
    cache.sweep
    assert_nil cache.read(:a)
    assert_equal "fresh value", cache.read(:b)
  end
end
