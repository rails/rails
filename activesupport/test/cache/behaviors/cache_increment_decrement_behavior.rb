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
    assert(missing.nil? || missing == 1)
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
    assert(missing.nil? || missing == -1)
  end
end
