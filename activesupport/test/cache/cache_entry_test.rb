# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/cache"

class CacheEntryTest < ActiveSupport::TestCase
  def test_expired
    entry = ActiveSupport::Cache::Entry.new("value")
    assert_not entry.expired?, "entry not expired"
    entry = ActiveSupport::Cache::Entry.new("value", expires_in: 60)
    assert_not entry.expired?, "entry not expired"
    Time.stub(:now, Time.at(entry.expires_at + 1)) do
      assert entry.expired?, "entry is expired"
    end
  end

  def test_initialize_with_expires_at
    entry = ActiveSupport::Cache::Entry.new("value", expires_in: 60)
    clone = ActiveSupport::Cache::Entry.new("value", expires_at: entry.expires_at)
    assert_equal entry.expires_at, clone.expires_at
  end

  def test_nil_is_not_serialized_or_deserialized
    entry = ActiveSupport::Cache::Entry.new(nil)
    assert_nil entry.value

    entry.serialize_value!
    assert_nil entry.value

    entry.deserialize_value!
    assert_nil entry.value
  end

  def test_numeric_is_not_serialized_or_deserialized
    entry = ActiveSupport::Cache::Entry.new(1)
    assert_equal 1, entry.value

    entry.serialize_value!
    assert_equal 1, entry.value

    entry.deserialize_value!
    assert_equal 1, entry.value
  end

  def test_true_is_not_serialized_or_deserialized
    entry = ActiveSupport::Cache::Entry.new(true)
    assert_equal true, entry.value

    entry.serialize_value!
    assert_equal true, entry.value

    entry.deserialize_value!
    assert_equal true, entry.value
  end

  def test_false_is_not_serialized_or_deserialized
    entry = ActiveSupport::Cache::Entry.new(false)
    assert_equal false, entry.value

    entry.serialize_value!
    assert_equal false, entry.value

    entry.deserialize_value!
    assert_equal false, entry.value
  end

  def test_string_serializes_by_duplication
    entry = ActiveSupport::Cache::Entry.new("foo")

    value = entry.value
    serialized = entry.serialize_value!
    deserialized = entry.deserialize_value!

    assert_equal "foo", value
    assert_equal "foo", deserialized
    assert_equal "foo", serialized

    assert_not_equal value.object_id, serialized.object_id
    assert_not_equal serialized.object_id, deserialized.object_id
    assert_not_equal deserialized.object_id, value.object_id
  end

  def test_hash_serializes_by_marshal
    entry = ActiveSupport::Cache::Entry.new([])

    value = entry.value
    serialized = entry.serialize_value!
    deserialized = entry.deserialize_value!

    assert_equal [], value
    assert_equal [], deserialized
    assert_equal Marshal.dump([]), serialized

    assert_not_equal value.object_id, deserialized.object_id
  end
end
