# frozen_string_literal: true

module CacheIncrementDecrementBehavior
  def test_increment
    key = SecureRandom.uuid
    @cache.write(key, 1, raw: true)
    assert_equal 1, @cache.read(key, raw: true).to_i
    assert_equal 2, @cache.increment(key)
    assert_equal 2, @cache.read(key, raw: true).to_i
    assert_equal 3, @cache.increment(key)
    assert_equal 3, @cache.read(key, raw: true).to_i

    missing = @cache.increment(SecureRandom.alphanumeric)
    assert_equal 1, missing
    missing = @cache.increment(SecureRandom.alphanumeric, 100)
    assert_equal 100, missing
  end

  def test_decrement
    key = SecureRandom.uuid
    @cache.write(key, 3, raw: true)
    assert_equal 3, @cache.read(key, raw: true).to_i
    assert_equal 2, @cache.decrement(key)
    assert_equal 2, @cache.read(key, raw: true).to_i
    assert_equal 1, @cache.decrement(key)
    assert_equal 1, @cache.read(key, raw: true).to_i

    missing = @cache.decrement(SecureRandom.alphanumeric)
    assert_equal @cache.is_a?(ActiveSupport::Cache::MemCacheStore) ? 0 : -1, missing
    missing = @cache.decrement(SecureRandom.alphanumeric, 100)
    assert_equal @cache.is_a?(ActiveSupport::Cache::MemCacheStore) ? 0 : -100, missing
  end

  def test_ttl_isnt_updated
    key = SecureRandom.uuid

    assert_equal 1, @cache.increment(key, expires_in: 1)
    assert_equal 2, @cache.increment(key, expires_in: 5000)

    # having to sleep two seconds in a test is bad, but we're testing
    # a wide range of backends with different TTL mechanisms, most without
    # subsecond granularity, so this is the only reliable way.
    sleep 2

    assert_nil @cache.read(key, raw: true)
  end
end
