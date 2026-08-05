class TallyingKeyStoreGraderTest < Minitest::Test
  def test_fetch_without_a_block_returns_nil_for_a_missing_key
    store = TallyingKeyStore.new
    assert_nil read_or_nil(store, :absent)
  end

  def test_fetch_with_a_block_returns_the_blocks_value_for_a_missing_key_without_storing_it
    store = TallyingKeyStore.new
    assert_equal :fallback, read_with_default(store, :absent, :fallback)
    assert_nil read_or_nil(store, :absent)
  end

  def test_fetch_returns_the_stored_value_when_present
    store = TallyingKeyStore.new
    store.store(:name, "ada")
    assert_equal "ada", read_or_nil(store, :name)
  end

  def test_hits_and_misses_are_counted_across_fetch_calls
    store = TallyingKeyStore.new
    store.store(:name, "ada")

    read_or_nil(store, :name)
    read_with_default(store, :missing, :fallback)
    read_or_nil(store, :missing)

    assert_equal 1, store.hits
    assert_equal 2, store.misses
  end

  private

  # Written against KeyStore's documented #fetch contract alone - exercised
  # here through the TallyingKeyStore subtype.
  def read_or_nil(store, key)
    store.fetch(key)
  end

  def read_with_default(store, key, default)
    store.fetch(key) { default }
  end
end
