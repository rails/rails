# frozen_string_literal: true

module CacheDeleteMatchedBehavior
  def test_delete_matched
    @cache.write("foo", "bar")
    @cache.write("fu", "baz")
    @cache.write("foo/bar", "baz")
    @cache.write("fu/baz", "bar")
    @cache.delete_matched(/oo/)
    assert !@cache.exist?("foo")
    assert @cache.exist?("fu")
    assert !@cache.exist?("foo/bar")
    assert @cache.exist?("fu/baz")
  end
end
