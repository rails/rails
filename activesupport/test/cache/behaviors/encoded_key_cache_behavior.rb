# frozen_string_literal: true

# https://rails.lighthouseapp.com/projects/8994/tickets/6225-memcachestore-cant-deal-with-umlauts-and-special-characters
# The error is caused by character encodings that can't be compared with ASCII-8BIT regular expressions and by special
# characters like the umlaut in UTF-8.
module EncodedKeyCacheBehavior
  Encoding.list.each do |encoding|
    define_method "test_#{encoding.name.underscore}_encoded_values" do
      key = (+"foo").force_encoding(encoding)
      assert @cache.write(key, "1", raw: true)
      assert_equal "1", @cache.read(key, raw: true)
      assert_equal "1", @cache.fetch(key, raw: true)
      assert @cache.delete(key)
      assert_equal "2", @cache.fetch(key, raw: true) { "2" }
      assert_equal 3, @cache.increment(key)
      assert_equal 2, @cache.decrement(key)
    end
  end

  def test_common_utf8_values
    key = (+"\xC3\xBCmlaut").force_encoding(Encoding::UTF_8)
    assert @cache.write(key, "1", raw: true)
    assert_equal "1", @cache.read(key, raw: true)
    assert_equal "1", @cache.fetch(key, raw: true)
    assert @cache.delete(key)
    assert_equal "2", @cache.fetch(key, raw: true) { "2" }
    assert_equal 3, @cache.increment(key)
    assert_equal 2, @cache.decrement(key)
  end

  def test_retains_encoding
    key = (+"\xC3\xBCmlaut").force_encoding(Encoding::UTF_8)
    assert @cache.write(key, "1", raw: true)
    assert_equal Encoding::UTF_8, key.encoding
  end
end
