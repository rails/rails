# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"
require_relative "../behaviors"
require "dalli"

# Emulates a latency on Dalli's back-end for the key latency to facilitate
# connection pool testing.
class SlowDalliClient < Dalli::Client
  def get(key, options = {})
    if key =~ /latency/
      sleep 3
    else
      super
    end
  end
end

class UnavailableDalliServer < Dalli::Server
  def alive?
    false
  end
end

class MemCacheStoreTest < ActiveSupport::TestCase
  begin
    ss = Dalli::Client.new("localhost:11211").stats
    raise Dalli::DalliError unless ss["localhost:11211"]

    MEMCACHE_UP = true
  rescue Dalli::DalliError
    $stderr.puts "Skipping memcached tests. Start memcached and try again."
    MEMCACHE_UP = false
  end

  def setup
    skip "memcache server is not up" unless MEMCACHE_UP

    @cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, expires_in: 60)
    @peek = ActiveSupport::Cache.lookup_store(:mem_cache_store)
    @data = @cache.instance_variable_get(:@data)
    @cache.clear
    @cache.silence!
    @cache.logger = ActiveSupport::Logger.new(File::NULL)
  end

  include CacheStoreBehavior
  include CacheStoreVersionBehavior
  include LocalCacheBehavior
  include CacheIncrementDecrementBehavior
  include CacheInstrumentationBehavior
  include EncodedKeyCacheBehavior
  include AutoloadingCacheBehavior
  include ConnectionPoolBehavior
  include FailureSafetyBehavior

  def test_raw_values
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, raw: true)
    cache.clear
    cache.write("foo", 2)
    assert_equal "2", cache.read("foo")
  end

  def test_raw_values_with_marshal
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, raw: true)
    cache.clear
    cache.write("foo", Marshal.dump([]))
    assert_equal [], cache.read("foo")
  end

  def test_local_cache_raw_values
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, raw: true)
    cache.clear
    cache.with_local_cache do
      cache.write("foo", 2)
      assert_equal "2", cache.read("foo")
    end
  end

  def test_increment_expires_in
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, raw: true)
    cache.clear
    assert_called_with cache.instance_variable_get(:@data), :incr, [ "foo", 1, 60 ] do
      cache.increment("foo", 1, expires_in: 60)
    end
  end

  def test_decrement_expires_in
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, raw: true)
    cache.clear
    assert_called_with cache.instance_variable_get(:@data), :decr, [ "foo", 1, 60 ] do
      cache.decrement("foo", 1, expires_in: 60)
    end
  end

  def test_local_cache_raw_values_with_marshal
    cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, raw: true)
    cache.clear
    cache.with_local_cache do
      cache.write("foo", Marshal.dump([]))
      assert_equal [], cache.read("foo")
    end
  end

  def test_read_should_return_a_different_object_id_each_time_it_is_called
    @cache.write("foo", "bar")
    value = @cache.read("foo")
    assert_not_equal value.object_id, @cache.read("foo").object_id
    value << "bingo"
    assert_not_equal value, @cache.read("foo")
  end

  private

    def store
      :mem_cache_store
    end

    def emulating_latency
      old_client = Dalli.send(:remove_const, :Client)
      Dalli.const_set(:Client, SlowDalliClient)

      yield
    ensure
      Dalli.send(:remove_const, :Client)
      Dalli.const_set(:Client, old_client)
    end

    def emulating_unavailability
      old_server = Dalli.send(:remove_const, :Server)
      Dalli.const_set(:Server, UnavailableDalliServer)

      yield ActiveSupport::Cache::MemCacheStore.new
    ensure
      Dalli.send(:remove_const, :Server)
      Dalli.const_set(:Server, old_server)
    end
end
