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
  REDIS_URL = ENV["REDIS_URL"] || "redis://localhost:6379/0"
  REDIS_URLS = ENV["REDIS_URLS"]&.split(",") || %w[ redis://localhost:6379/0 redis://localhost:6379/1 ]

  if ENV["CI"]
    REDIS_UP = true
  else
    begin
      redis = Redis.new(url: REDIS_URL)
      redis.ping

      REDIS_UP = true
    rescue Redis::BaseConnectionError
      $stderr.puts "Skipping redis tests. Start redis and try again."
      REDIS_UP = false
    end
  end

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
        url: REDIS_URL,
        connect_timeout: 20, read_timeout: 1, write_timeout: 1,
        reconnect_attempts: 0, driver: DRIVER
      ] do
        build url: REDIS_URL
      end
    end

    test "one URL uses Redis client" do
      assert_called_with Redis, :new, [
        url: REDIS_URL,
        connect_timeout: 20, read_timeout: 1, write_timeout: 1,
        reconnect_attempts: 0, driver: DRIVER
      ] do
        build url: [ REDIS_URL ]
      end
    end

    test "multiple URLs uses Redis::Distributed client" do
      assert_called_with Redis, :new, [
        [ url: REDIS_URLS.first,
          connect_timeout: 20, read_timeout: 1, write_timeout: 1,
          reconnect_attempts: 0, driver: DRIVER ],
        [ url: REDIS_URLS.last,
          connect_timeout: 20, read_timeout: 1, write_timeout: 1,
          reconnect_attempts: 0, driver: DRIVER ],
      ], returns: Redis.new do
        @cache = build url: REDIS_URLS
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

    test "fetch caches nil" do
      cache = build
      cache.write("foo", nil)
      assert_not_called(cache, :write) do
        assert_nil cache.fetch("foo") { "baz" }
      end
    end

    test "skip_nil is passed to ActiveSupport::Cache" do
      cache = build(skip_nil: true)
      cache.clear
      assert_not_called(cache, :write) do
        assert_nil cache.fetch("foo") { nil }
        assert_equal false, cache.exist?("foo")
      end
    end

    private
      def build(**kwargs)
        ActiveSupport::Cache::RedisCacheStore.new(driver: DRIVER, **kwargs).tap(&:redis)
      end
  end

  class StoreTest < ActiveSupport::TestCase
    setup do
      @cache = nil
      skip "redis server is not up" unless REDIS_UP
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

    def test_write_expires_at
      @cache.write "key_with_expires_at", "bar", expires_at: 30.minutes.from_now
      assert @cache.redis.ttl("#{@namespace}:key_with_expires_at") > 0
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

  class OptimizedRedisCacheStoreCommonBehaviorTest < RedisCacheStoreCommonBehaviorTest
    def before_setup
      @previous_format = ActiveSupport::Cache.format_version
      ActiveSupport::Cache.format_version = 7.0
      super
    end

    def test_forward_compatibility
      previous_format = ActiveSupport::Cache.format_version
      ActiveSupport::Cache.format_version = 6.1
      @old_store = lookup_store
      ActiveSupport::Cache.format_version = previous_format

      key = SecureRandom.uuid
      value = SecureRandom.alphanumeric
      @old_store.write(key, value)
      assert_equal value, @cache.read(key)
    end

    def test_backward_compatibility
      previous_format = ActiveSupport::Cache.format_version
      ActiveSupport::Cache.format_version = 6.1
      @old_store = lookup_store
      ActiveSupport::Cache.format_version = previous_format

      key = SecureRandom.uuid
      value = SecureRandom.alphanumeric
      @cache.write(key, value)
      assert_equal value, @old_store.read(key)
    end

    def after_teardown
      super
      ActiveSupport::Cache.format_version = @previous_format
    end
  end

  class ConnectionPoolBehaviourTest < StoreTest
    include ConnectionPoolBehavior

    def test_deprecated_connection_pool_works
      assert_deprecated do
        cache = ActiveSupport::Cache.lookup_store(:redis_cache_store, pool_size: 2, pool_timeout: 1)
        pool = cache.redis # loads 'connection_pool' gem
        assert_kind_of ::ConnectionPool, pool
        assert_equal 2, pool.size
        assert_equal 1, pool.instance_variable_get(:@timeout)
      end
    end

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
        { url: REDIS_URLS }
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

  class FailureRaisingFromUnavailableClientTest < StoreTest
    include FailureRaisingBehavior

    private
      def emulating_unavailability
        old_client = Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, UnavailableRedisClient)

        yield ActiveSupport::Cache::RedisCacheStore.new(namespace: @namespace,
                                                        error_handler: -> (method:, returning:, exception:) { raise exception })
      ensure
        Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, old_client)
      end
  end

  class FailureRaisingFromMaxClientsReachedErrorTest < StoreTest
    include FailureRaisingBehavior

    private
      def emulating_unavailability
        old_client = Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, MaxClientsReachedRedisClient)

        yield ActiveSupport::Cache::RedisCacheStore.new(namespace: @namespace,
                                                        error_handler: -> (method:, returning:, exception:) { raise exception })
      ensure
        Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, old_client)
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
      prefix = SecureRandom.alphanumeric
      key = "#{prefix}#{SecureRandom.uuid}"
      @cache.write(key, "bar")

      other_key = SecureRandom.uuid
      @cache.write(other_key, SecureRandom.alphanumeric)
      @cache.delete_matched("#{prefix}*")
      assert_not @cache.exist?(key)
      assert @cache.exist?(other_key)
    end

    test "fails with regexp matchers" do
      assert_raise ArgumentError do
        @cache.delete_matched(/OO/i)
      end
    end
  end

  class ClearTest < StoreTest
    test "clear all cache key" do
      key = SecureRandom.uuid
      other_key = SecureRandom.uuid
      @cache.write(key, SecureRandom.uuid)
      @cache.write(other_key, SecureRandom.uuid)
      @cache.clear
      assert_not @cache.exist?(key)
      assert_not @cache.exist?(other_key)
    end

    test "only clear namespace cache key" do
      key = SecureRandom.uuid
      other_key = SecureRandom.uuid

      @cache.write(key, SecureRandom.alphanumeric)
      @cache.redis.set(other_key, SecureRandom.alphanumeric)
      @cache.clear

      assert_not @cache.exist?(key)
      assert @cache.redis.exists?(other_key)
      @cache.redis.del(other_key)
    end

    test "clear all cache key with Redis::Distributed" do
      cache = ActiveSupport::Cache::RedisCacheStore.new(
        url: REDIS_URLS,
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
