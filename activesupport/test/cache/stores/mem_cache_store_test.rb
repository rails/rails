# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require_relative "../behaviors"
require "dalli"

# Emulates a latency on Dalli's back-end for the key latency to facilitate
# connection pool testing.
class SlowDalliClient < Dalli::Client
  def get(key, options = {})
    if /latency/.match?(key)
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
    servers = ENV["MEMCACHE_SERVERS"] || "localhost:11211"
    ss = Dalli::Client.new(servers).stats
    raise Dalli::DalliError unless ss[servers]

    MEMCACHE_UP = true
  rescue Dalli::DalliError
    $stderr.puts "Skipping memcached tests. Start memcached and try again."
    MEMCACHE_UP = false
  end

  def lookup_store(options = {})
    ActiveSupport::Cache.lookup_store(*store, { namespace: @namespace }.merge(options))
  end

  def setup
    skip "memcache server is not up" unless MEMCACHE_UP

    @namespace = "test-#{SecureRandom.hex}"
    @cache = lookup_store(expires_in: 60)
    @peek = lookup_store
    @data = @cache.instance_variable_get(:@data)
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

  # Overrides test from LocalCacheBehavior in order to stub out the cache clear
  # and replace it with a delete.
  def test_clear_also_clears_local_cache
    client = @cache.instance_variable_get(:@data)
    key = "#{@namespace}:foo"
    client.stub(:flush_all, -> { client.delete(key) }) do
      super
    end
  end

  def test_raw_values
    cache = lookup_store(raw: true)
    cache.write("foo", 2)
    assert_equal "2", cache.read("foo")
  end

  def test_raw_values_with_marshal
    cache = lookup_store(raw: true)
    cache.write("foo", Marshal.dump([]))
    assert_equal Marshal.dump([]), cache.read("foo")
  end

  def test_local_cache_raw_values
    cache = lookup_store(raw: true)
    cache.with_local_cache do
      cache.write("foo", 2)
      assert_equal "2", cache.read("foo")
    end
  end

  def test_increment_expires_in
    cache = lookup_store(raw: true, namespace: nil)
    assert_called_with cache.instance_variable_get(:@data), :incr, [ "foo", 1, 60 ] do
      cache.increment("foo", 1, expires_in: 60)
    end
  end

  def test_decrement_expires_in
    cache = lookup_store(raw: true, namespace: nil)
    assert_called_with cache.instance_variable_get(:@data), :decr, [ "foo", 1, 60 ] do
      cache.decrement("foo", 1, expires_in: 60)
    end
  end

  def test_local_cache_raw_values_with_marshal
    cache = lookup_store(raw: true)
    cache.with_local_cache do
      cache.write("foo", Marshal.dump([]))
      assert_equal Marshal.dump([]), cache.read("foo")
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
      [:mem_cache_store, ENV["MEMCACHE_SERVERS"] || "localhost:11211"]
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
