# frozen_string_literal: true

require_relative '../abstract_unit'
require 'active_support/cache'
require 'dalli'

class CacheStoreSettingTest < ActiveSupport::TestCase
  def test_memory_store_gets_created_if_no_arguments_passed_to_lookup_store_method
    store = ActiveSupport::Cache.lookup_store
    assert_kind_of(ActiveSupport::Cache::MemoryStore, store)
  end

  def test_memory_store
    store = ActiveSupport::Cache.lookup_store :memory_store
    assert_kind_of(ActiveSupport::Cache::MemoryStore, store)
  end

  def test_file_fragment_cache_store
    store = ActiveSupport::Cache.lookup_store :file_store, '/path/to/cache/directory'
    assert_kind_of(ActiveSupport::Cache::FileStore, store)
    assert_equal '/path/to/cache/directory', store.cache_path
  end

  def test_mem_cache_fragment_cache_store
    assert_called_with(Dalli::Client, :new, [%w[localhost], {}]) do
      store = ActiveSupport::Cache.lookup_store :mem_cache_store, 'localhost'
      assert_kind_of(ActiveSupport::Cache::MemCacheStore, store)
    end
  end

  def test_mem_cache_fragment_cache_store_with_given_mem_cache
    mem_cache = Dalli::Client.new
    assert_not_called(Dalli::Client, :new) do
      store = ActiveSupport::Cache.lookup_store :mem_cache_store, mem_cache
      assert_kind_of(ActiveSupport::Cache::MemCacheStore, store)
    end
  end

  def test_mem_cache_fragment_cache_store_with_not_dalli_client
    assert_not_called(Dalli::Client, :new) do
      memcache = Object.new
      assert_raises(ArgumentError) do
        ActiveSupport::Cache.lookup_store :mem_cache_store, memcache
      end
    end
  end

  def test_mem_cache_fragment_cache_store_with_multiple_servers
    assert_called_with(Dalli::Client, :new, [%w[localhost 192.168.1.1], {}]) do
      store = ActiveSupport::Cache.lookup_store :mem_cache_store, 'localhost', '192.168.1.1'
      assert_kind_of(ActiveSupport::Cache::MemCacheStore, store)
    end
  end

  def test_mem_cache_fragment_cache_store_with_options
    assert_called_with(Dalli::Client, :new, [%w[localhost 192.168.1.1], { timeout: 10 }]) do
      store = ActiveSupport::Cache.lookup_store :mem_cache_store, 'localhost', '192.168.1.1', namespace: 'foo', timeout: 10
      assert_kind_of(ActiveSupport::Cache::MemCacheStore, store)
      assert_equal 'foo', store.options[:namespace]
    end
  end

  def test_object_assigned_fragment_cache_store
    store = ActiveSupport::Cache.lookup_store ActiveSupport::Cache::FileStore.new('/path/to/cache/directory')
    assert_kind_of(ActiveSupport::Cache::FileStore, store)
    assert_equal '/path/to/cache/directory', store.cache_path
  end

  def test_redis_cache_store_with_single_array_object
    cache_store = [:redis_cache_store, namespace: 'foo']

    store = ActiveSupport::Cache.lookup_store(cache_store)
    assert_kind_of ActiveSupport::Cache::RedisCacheStore, store
    assert_equal 'foo', store.options[:namespace]
  end

  def test_redis_cache_store_with_ordered_options
    options = ActiveSupport::OrderedOptions.new
    options.update namespace: 'foo'

    store = ActiveSupport::Cache.lookup_store :redis_cache_store, options
    assert_kind_of(ActiveSupport::Cache::RedisCacheStore, store)
    assert_equal 'foo', store.options[:namespace]
  end
end
