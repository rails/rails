# frozen_string_literal: true
module CacheIncrementDecrementBehavior
  def test_increment
    @cache.write("foo", 1, raw: true)
    assert_equal 1, @cache.read("foo").to_i
    assert_equal 2, @cache.increment("foo")
    assert_equal 2, @cache.read("foo").to_i
    assert_equal 3, @cache.increment("foo")
    assert_equal 3, @cache.read("foo").to_i
    assert_nil @cache.increment("bar")
  end

  def test_decrement
    @cache.write("foo", 3, raw: true)
    assert_equal 3, @cache.read("foo").to_i
    assert_equal 2, @cache.decrement("foo")
    assert_equal 2, @cache.read("foo").to_i
    assert_equal 1, @cache.decrement("foo")
    assert_equal 1, @cache.read("foo").to_i
    assert_nil @cache.decrement("bar")
  end
end
