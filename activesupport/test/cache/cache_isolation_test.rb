# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/cache"
require "active_support/testing/cache_isolation"

# Mock Rails.cache for testing
module Rails
  class << self
    attr_accessor :cache
  end
end

class CacheIsolationTest < ActiveSupport::TestCase
  def setup
    Rails.cache = ActiveSupport::Cache::MemoryStore.new(namespace: "test_app")
    @original_namespace = Rails.cache.namespace
  end

  test "isolate_cache_namespace randomizes Rails.cache namespace" do
    # Manually call the private method
    send(:isolate_cache_namespace)

    assert_not_equal @original_namespace, Rails.cache.namespace
    assert_match(/^[a-f0-9]{12}r:test_app$/, Rails.cache.namespace)
  end

  test "multiple calls replace the random prefix" do
    send(:isolate_cache_namespace)
    first_namespace = Rails.cache.namespace

    send(:isolate_cache_namespace)
    second_namespace = Rails.cache.namespace

    assert_not_equal first_namespace, second_namespace
    assert first_namespace.end_with?("r:test_app")
    assert second_namespace.end_with?("r:test_app")
  end

  test "isolation works with complex namespaces" do
    Rails.cache = ActiveSupport::Cache::MemoryStore.new(namespace: "app:v1:production")

    send(:isolate_cache_namespace)

    assert_match(/^[a-f0-9]{12}r:app:v1:production$/, Rails.cache.namespace)
  end

  test "isolation skips non-ActiveSupport cache stores" do
    Rails.cache = Object.new
    original = Rails.cache

    send(:isolate_cache_namespace)

    assert_equal original, Rails.cache
  end

  test "isolation skips cache stores without namespace support" do
    mock_cache = Object.new
    def mock_cache.is_a?(klass)
      klass == ActiveSupport::Cache::Store
    end
    Rails.cache = mock_cache
    original = Rails.cache

    send(:isolate_cache_namespace)

    assert_equal original, Rails.cache
  end
end
