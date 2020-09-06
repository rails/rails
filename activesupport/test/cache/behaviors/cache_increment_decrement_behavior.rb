# frozen_string_literal: true

module CacheIncrementDecrementBehavior
  def test_increment
    @cache.write('foo', 1, raw: true)
    assert_equal 1, @cache.read('foo', raw: true).to_i
    assert_equal 2, @cache.increment('foo')
    assert_equal 2, @cache.read('foo', raw: true).to_i
    assert_equal 3, @cache.increment('foo')
    assert_equal 3, @cache.read('foo', raw: true).to_i

    missing = @cache.increment('bar')
    assert(missing.nil? || missing == 1)
  end

  def test_decrement
    @cache.write('foo', 3, raw: true)
    assert_equal 3, @cache.read('foo', raw: true).to_i
    assert_equal 2, @cache.decrement('foo')
    assert_equal 2, @cache.read('foo', raw: true).to_i
    assert_equal 1, @cache.decrement('foo')
    assert_equal 1, @cache.read('foo', raw: true).to_i

    missing = @cache.decrement('bar')
    assert(missing.nil? || missing == -1)
  end
end
