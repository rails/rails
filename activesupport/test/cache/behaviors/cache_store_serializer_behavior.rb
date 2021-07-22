# frozen_string_literal: true
module CacheStoreSerializerBehavior
  def test_json_to_marshal_serializer_fallback_compatibility
    previous_serializer = ActiveSupport::Cache.cache_serializer
    ActiveSupport::Cache.cache_serializer = :marshal
    @old_store = lookup_store
    ActiveSupport::Cache.cache_serializer = previous_serializer

    @old_store.write("foo", "bar")
    assert_equal "bar", @cache.read("foo")
  end

  def test_marshal_to_json_serializer_fallback_compatibility
    previous_serializer = ActiveSupport::Cache.cache_serializer
    ActiveSupport::Cache.cache_serializer = :marshal
    @old_store = lookup_store
    ActiveSupport::Cache.cache_serializer = previous_serializer

    @cache.write("foo", "bar")
    assert_equal "bar", @old_store.read("foo")
  end
end
