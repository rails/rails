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
  include EncodedKeyCacheBehavior
  include AutoloadingCacheBehavior

  def test_connection_pool
    emulating_latency do
      begin
        cache = ActiveSupport::Cache.lookup_store(:mem_cache_store, pool_size: 2, pool_timeout: 1)
        cache.clear

        threads = []

        assert_raises Timeout::Error do
          # One of the three threads will fail in 1 second because our pool size
          # is only two.
          3.times do
            threads << Thread.new do
              cache.read("latency")
            end
          end

          threads.each(&:join)
        end
      ensure
        threads.each(&:kill)
      end
    end
  end

  def test_no_connection_pool
    emulating_latency do
      begin
        cache = ActiveSupport::Cache.lookup_store(:mem_cache_store)
        cache.clear

        threads = []

        assert_nothing_raised do
          # Default connection pool size is 5, assuming 10 will make sure that
          # the connection pool isn't used at all.
          10.times do
            threads << Thread.new do
              cache.read("latency")
            end
          end

          threads.each(&:join)
        end
      ensure
        threads.each(&:kill)
      end
    end
  end

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

    def emulating_latency
      old_client = Dalli.send(:remove_const, :Client)
      Dalli.const_set(:Client, SlowDalliClient)

      yield
    ensure
      Dalli.send(:remove_const, :Client)
      Dalli.const_set(:Client, old_client)
    end
end
