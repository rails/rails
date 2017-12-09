# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"

class CacheEntryTest < ActiveSupport::TestCase
  def test_expired
    entry = ActiveSupport::Cache::Entry.new("value")
    assert !entry.expired?, "entry not expired"
    entry = ActiveSupport::Cache::Entry.new("value", expires_in: 60)
    assert !entry.expired?, "entry not expired"
    Time.stub(:now, Time.now + 61) do
      assert entry.expired?, "entry is expired"
    end
  end

  def test_compressed_values
    value = "value" * 100
    entry = ActiveSupport::Cache::Entry.new(value, compress: true, compress_threshold: 1)
    assert_equal value, entry.value
    assert(value.bytesize > entry.size, "value is compressed")
  end

  def test_compressed_by_default
    value = "value" * 100
    entry = ActiveSupport::Cache::Entry.new(value, compress_threshold: 1)
    assert_equal value, entry.value
    assert(value.bytesize > entry.size, "value is compressed")
  end

  def test_uncompressed_values
    value = "value" * 100
    entry = ActiveSupport::Cache::Entry.new(value, compress: false)
    assert_equal value, entry.value
    assert_equal value.bytesize, entry.size
  end
end
