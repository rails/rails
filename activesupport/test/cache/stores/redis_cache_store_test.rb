# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require "active_support/cache/redis_cache_store"
require_relative "../behaviors"

driver_name = %w[ ruby hiredis ].include?(ENV["REDIS_DRIVER"]) ? ENV["REDIS_DRIVER"] : "hiredis"
driver = Object.const_get("Redis::Connection::#{driver_name.camelize}")

Redis::Connection.drivers.clear
Redis::Connection.drivers.append(driver)

# Emulates a latency on Redis's back-end for the key latency to facilitate
# connection pool testing.
class SlowRedis < Redis
  def get(key)
    if /latency/.match?(key)
      sleep 3
      super
    else
      super
    end
  end
end

module ActiveSupport::Cache::RedisCacheStoreTests
  DRIVER = %w[ ruby hiredis ].include?(ENV["REDIS_DRIVER"]) ? ENV["REDIS_DRIVER"] : "hiredis"

  class LookupTest < ActiveSupport::TestCase
    test "may be looked up as :redis_cache_store" do
      assert_kind_of ActiveSupport::Cache::RedisCacheStore,
        ActiveSupport::Cache.lookup_store(:redis_cache_store)
    end
  end

  class InitializationTest < ActiveSupport::TestCase
    test "omitted URL uses Redis client with default settings" do
      assert_called_with Redis, :new, [
        url: nil,
        connect_timeout: 20, read_timeout: 1, write_timeout: 1,
        reconnect_attempts: 0, driver: DRIVER
      ] do
        build
      end
    end

    test "no URLs uses Redis client with default settings" do
      assert_called_with Redis, :new, [
        url: nil,
        connect_timeout: 20, read_timeout: 1, write_timeout: 1,
        reconnect_attempts: 0, driver: DRIVER
      ] do
        build url: []
      end
    end

    test "singular URL uses Redis client" do
      assert_called_with Redis, :new, [
        url: "redis://localhost:6379/0",
        connect_timeout: 20, read_timeout: 1, write_timeout: 1,
        reconnect_attempts: 0, driver: DRIVER
      ] do
        build url: "redis://localhost:6379/0"
      end
    end

    test "one URL uses Redis client" do
      assert_called_with Redis, :new, [
        url: "redis://localhost:6379/0",
        connect_timeout: 20, read_timeout: 1, write_timeout: 1,
        reconnect_attempts: 0, driver: DRIVER
      ] do
        build url: %w[ redis://localhost:6379/0 ]
      end
    end

    test "multiple URLs uses Redis::Distributed client" do
      assert_called_with Redis, :new, [
        [ url: "redis://localhost:6379/0",
          connect_timeout: 20, read_timeout: 1, write_timeout: 1,
          reconnect_attempts: 0, driver: DRIVER ],
        [ url: "redis://localhost:6379/1",
          connect_timeout: 20, read_timeout: 1, write_timeout: 1,
          reconnect_attempts: 0, driver: DRIVER ],
      ], returns: Redis.new do
        @cache = build url: %w[ redis://localhost:6379/0 redis://localhost:6379/1 ]
        assert_kind_of ::Redis::Distributed, @cache.redis
      end
    end

    test "block argument uses yielded client" do
      block = -> { :custom_redis_client }
      assert_called block, :call do
        build redis: block
      end
    end

    test "instance of Redis uses given instance" do
      redis_instance = Redis.new
      @cache = build(redis: redis_instance)
      assert_same @cache.redis, redis_instance
    end

    private
      def build(**kwargs)
        ActiveSupport::Cache::RedisCacheStore.new(driver: DRIVER, **kwargs).tap(&:redis)
      end
  end

  class StoreTest < ActiveSupport::TestCase
    setup do
      @namespace = "test-#{SecureRandom.hex}"

      @cache = lookup_store(expires_in: 60)
      # @cache.logger = Logger.new($stdout)  # For test debugging

      # For LocalCacheBehavior tests
      @peek = lookup_store(expires_in: 60)
    end

    def lookup_store(options = {})
      ActiveSupport::Cache.lookup_store(:redis_cache_store, { timeout: 0.1, namespace: @namespace, driver: DRIVER }.merge(options))
    end

    teardown do
      @cache.clear
      @cache.redis.disconnect!
    end
  end

  class RedisCacheStoreCommonBehaviorTest < StoreTest
    include CacheStoreBehavior
    include CacheStoreVersionBehavior
    include CacheStoreCoderBehavior
    include LocalCacheBehavior
    include CacheIncrementDecrementBehavior
    include CacheInstrumentationBehavior
    include EncodedKeyCacheBehavior

    def test_fetch_multi_uses_redis_mget
      assert_called(@cache.redis, :mget, returns: []) do
        @cache.fetch_multi("a", "b", "c") do |key|
          key * 2
        end
      end
    end

    def test_fetch_multi_with_namespace
      assert_called_with(@cache.redis, :mget, ["custom-namespace:a", "custom-namespace:b", "custom-namespace:c"], returns: []) do
        @cache.fetch_multi("a", "b", "c", namespace: "custom-namespace") do |key|
          key * 2
        end
      end
    end

    def test_fetch_multi_without_names
      assert_not_called(@cache.redis, :mget) do
        @cache.fetch_multi() { }
      end
    end

    def test_increment_expires_in
      assert_called_with @cache.redis, :incrby, [ "#{@namespace}:foo", 1 ] do
        assert_called_with @cache.redis, :expire, [ "#{@namespace}:foo", 60 ] do
          @cache.increment "foo", 1, expires_in: 60
        end
      end

      # key and ttl exist
      @cache.redis.setex "#{@namespace}:bar", 120, 1
      assert_not_called @cache.redis, :expire do
        @cache.increment "bar", 1, expires_in: 2.minutes
      end

      # key exist but not have expire
      @cache.redis.set "#{@namespace}:dar", 10
      assert_called_with @cache.redis, :expire, [ "#{@namespace}:dar", 60 ] do
        @cache.increment "dar", 1, expires_in: 60
      end
    end

    def test_decrement_expires_in
      assert_called_with @cache.redis, :decrby, [ "#{@namespace}:foo", 1 ] do
        assert_called_with @cache.redis, :expire, [ "#{@namespace}:foo", 60 ] do
          @cache.decrement "foo", 1, expires_in: 60
        end
      end

      # key and ttl exist
      @cache.redis.setex "#{@namespace}:bar", 120, 1
      assert_not_called @cache.redis, :expire do
        @cache.decrement "bar", 1, expires_in: 2.minutes
      end

      # key exist but not have expire
      @cache.redis.set "#{@namespace}:dar", 10
      assert_called_with @cache.redis, :expire, [ "#{@namespace}:dar", 60 ] do
        @cache.decrement "dar", 1, expires_in: 60
      end
    end

    def test_large_string_with_default_compression_settings
      assert_compressed(LARGE_STRING)
    end

    def test_large_object_with_default_compression_settings
      assert_compressed(LARGE_OBJECT)
    end
  end

  class ConnectionPoolBehaviourTest < StoreTest
    include ConnectionPoolBehavior

    private
      def store
        [:redis_cache_store]
      end

      def emulating_latency
        old_redis = Object.send(:remove_const, :Redis)
        Object.const_set(:Redis, SlowRedis)

        yield
      ensure
        Object.send(:remove_const, :Redis)
        Object.const_set(:Redis, old_redis)
      end
  end

  class RedisDistributedConnectionPoolBehaviourTest < ConnectionPoolBehaviourTest
    private
      def store_options
        { url: [ENV["REDIS_URL"] || "redis://localhost:6379/0"] * 2 }
      end
  end

  class StoreAPITest < StoreTest
  end

  class UnavailableRedisClient < Redis::Client
    def ensure_connected
      raise Redis::BaseConnectionError
    end
  end

  class MaxClientsReachedRedisClient < Redis::Client
    def ensure_connected
      raise Redis::CommandError
    end
  end

  class FailureSafetyFromUnavailableClientTest < StoreTest
    include FailureSafetyBehavior

    private
      def emulating_unavailability
        old_client = Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, UnavailableRedisClient)

        yield ActiveSupport::Cache::RedisCacheStore.new(namespace: @namespace)
      ensure
        Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, old_client)
      end
  end

  class FailureSafetyFromMaxClientsReachedErrorTest < StoreTest
    include FailureSafetyBehavior

    private
      def emulating_unavailability
        old_client = Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, MaxClientsReachedRedisClient)

        yield ActiveSupport::Cache::RedisCacheStore.new
      ensure
        Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, old_client)
      end
  end

  class DeleteMatchedTest < StoreTest
    test "deletes keys matching glob" do
      @cache.write("foo", "bar")
      @cache.write("fu", "baz")
      @cache.delete_matched("foo*")
      assert_not @cache.exist?("foo")
      assert @cache.exist?("fu")
    end

    test "fails with regexp matchers" do
      assert_raise ArgumentError do
        @cache.delete_matched(/OO/i)
      end
    end
  end

  class ClearTest < StoreTest
    test "clear all cache key" do
      @cache.write("foo", "bar")
      @cache.write("fu", "baz")
      @cache.clear
      assert_not @cache.exist?("foo")
      assert_not @cache.exist?("fu")
    end

    test "only clear namespace cache key" do
      @cache.write("foo", "bar")
      @cache.redis.set("fu", "baz")
      @cache.clear
      assert_not @cache.exist?("foo")
      assert @cache.redis.exists?("fu")
    end

    test "clear all cache key with Redis::Distributed" do
      cache = ActiveSupport::Cache::RedisCacheStore.new(
        url: %w[redis://localhost:6379/0, redis://localhost:6379/1],
        timeout: 0.1, namespace: @namespace, expires_in: 60, driver: DRIVER)
      cache.write("foo", "bar")
      cache.write("fu", "baz")
      cache.clear
      assert_not cache.exist?("foo")
      assert_not cache.exist?("fu")
    end
  end

  class RawTest < StoreTest
    test "does not compress values read with \"raw\" enabled" do
      @cache.write("foo", "bar", raw: true)

      assert_not_called_on_instance_of ActiveSupport::Cache::Entry, :compressed do
        @cache.read("foo", raw: true)
      end
    end
  end
end
