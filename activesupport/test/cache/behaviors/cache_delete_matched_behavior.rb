# frozen_string_literal: true

module CacheDeleteMatchedBehavior
  def test_delete_matched
    prefix = SecureRandom.alphanumeric # foo
    @cache.write(prefix, SecureRandom.alphanumeric)

    second_prefix = SecureRandom.alphanumeric # fu
    @cache.write(second_prefix, SecureRandom.alphanumeric)

    key = "#{prefix}/#{SecureRandom.uuid}"  # foo/bar
    @cache.write(key, SecureRandom.alphanumeric)

    other_key = "#{second_prefix}/#{SecureRandom.uuid}" # fu/baz
    @cache.write(other_key, SecureRandom.alphanumeric)

    @cache.delete_matched(/#{prefix}/) # foo

    assert_not @cache.exist?(prefix)
    assert @cache.exist?(second_prefix)
    assert_not @cache.exist?(key)
    assert @cache.exist?(other_key)
  end
end
