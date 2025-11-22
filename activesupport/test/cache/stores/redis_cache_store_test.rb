# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require "active_support/cache/redis_cache_store"
require_relative "../behaviors"

# Emulates a latency on Redis's back-end for the key latency to facilitate
# connection pool testing.
class SlowRedis < Redis
  def get(key)
    if /latency/.match?(key)
      sleep 0.2
      super
    else
      super
    end
  end
end

module ActiveSupport::Cache::RedisCacheStoreTests
  REDIS_URL = ENV["REDIS_URL"] || "redis://localhost:6379/0"
  REDIS_URLS = ENV["REDIS_URLS"]&.split(",") || %w[ redis://localhost:6379/0 redis://localhost:6379/1 ]

  if ENV["BUILDKITE"]
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

  class LookupTest < ActiveSupport::TestCase
    test "may be looked up as :redis_cache_store" do
      assert_kind_of ActiveSupport::Cache::RedisCacheStore,
        ActiveSupport::Cache.lookup_store(:redis_cache_store)
    end
  end

  class InitializationTest < ActiveSupport::TestCase
    test "omitted URL uses Redis client with default settings" do
      assert_called_with Redis, :new, [
        connect_timeout: 1, read_timeout: 1, write_timeout: 1
      ] do
        build
      end
    end

    test "no URLs uses Redis client with default settings" do
      assert_called_with Redis, :new, [
        connect_timeout: 1, read_timeout: 1, write_timeout: 1
      ] do
        build url: []
      end
    end

    test "singular URL uses Redis client" do
      assert_called_with Redis, :new, [
        url: REDIS_URL,
        connect_timeout: 1, read_timeout: 1, write_timeout: 1
      ] do
        build url: REDIS_URL
      end
    end

    test "one URL uses Redis client" do
      assert_called_with Redis, :new, [
        url: REDIS_URL,
        connect_timeout: 1, read_timeout: 1, write_timeout: 1
      ] do
        build url: [ REDIS_URL ]
      end
    end

    test "multiple URLs uses Redis::Distributed client" do
      default_args = {
        connect_timeout: 1,
        read_timeout: 1,
        write_timeout: 1
      }

      mock = Minitest::Mock.new
      mock.expect(:call, Redis.new, [{ url: REDIS_URLS.first }.merge(default_args)])
      mock.expect(:call, Redis.new, [{ url: REDIS_URLS.last }.merge(default_args)])

      Redis.stub(:new, mock) do
        @cache = build url: REDIS_URLS
        assert_kind_of ::Redis::Distributed, @cache.redis
      end

      assert_mock(mock)
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

    test "validate pool arguments" do
      assert_raises TypeError do
        build(url: REDIS_URL, pool: { size: [] })
      end

      assert_raises TypeError do
        build(url: REDIS_URL, pool: { timeout: [] })
      end

      build(url: REDIS_URL, pool: { size: "12", timeout: "1.5" })
    end

    test "instantiating the store doesn't connect to Redis" do
      assert_nothing_raised do
        build(url: "redis://localhost:1")
      end
    end

    private
      def build(**kwargs)
        ActiveSupport::Cache::RedisCacheStore.new(pool: false, **kwargs).tap(&:redis)
      end
  end

  class StoreTest < ActiveSupport::TestCase
    setup do
      @cache = nil
      skip "Redis server is not up" unless REDIS_UP
      @namespace = "test-#{SecureRandom.hex}"

      @cache = lookup_store(expires_in: 60)
      # @cache.logger = Logger.new($stdout)  # For test debugging

      @cache_no_ttl = lookup_store

      # For LocalCacheBehavior tests
      @peek = lookup_store(expires_in: 60)
    end

    def lookup_store(options = {})
      ActiveSupport::Cache.lookup_store(:redis_cache_store, { timeout: 0.1, namespace: @namespace, pool: false }.merge(options))
    end

    teardown do
      @cache.clear
      @cache.redis.with do |r|
        r.respond_to?(:on_each_node, true) ? r.send(:on_each_node, :disconnect!) : r.disconnect!
      end
    end
  end

  class RedisCacheStoreCommonBehaviorTest < StoreTest
    include CacheStoreBehavior
    include CacheStoreVersionBehavior
    include CacheStoreCoderBehavior
    include CacheStoreCompressionBehavior
    include CacheStoreFormatVersionBehavior
    include CacheStoreSerializerBehavior
    include LocalCacheBehavior
    include CacheIncrementDecrementBehavior
    include CacheInstrumentationBehavior
    include CacheLoggingBehavior
    include EncodedKeyCacheBehavior

    def test_fetch_multi_uses_redis_mget
      assert_called(redis_backend, :mget, returns: []) do
        @cache.fetch_multi("a", "b", "c") do |key|
          key * 2
        end
      end
    end

    def test_fetch_multi_with_namespace
      assert_called_with(redis_backend, :mget, ["custom-namespace:a", "custom-namespace:b", "custom-namespace:c"], returns: []) do
        @cache.fetch_multi("a", "b", "c", namespace: "custom-namespace") do |key|
          key * 2
        end
      end
    end

    def test_write_expires_at
      @cache.write "key_with_expires_at", "bar", expires_at: 30.minutes.from_now
      redis_backend do |r|
        assert r.ttl("#{@namespace}:key_with_expires_at") > 0
      end
    end

    def test_write_with_unless_exist
      assert_equal true, @cache.write("foo", 1)
      assert_equal false, @cache.write("foo", 1, unless_exist: true)
    end

    def test_increment_ttl
      # existing key
      redis_backend(@cache_no_ttl) { |r| r.set "#{@namespace}:jar", 10 }
      @cache_no_ttl.increment "jar", 1
      redis_backend(@cache_no_ttl) do |r|
        assert r.get("#{@namespace}:jar").to_i == 11
        assert r.ttl("#{@namespace}:jar") < 0
      end

      # new key
      @cache_no_ttl.increment "kar", 1
      redis_backend(@cache_no_ttl) do |r|
        assert r.get("#{@namespace}:kar").to_i == 1
        assert r.ttl("#{@namespace}:kar") < 0
      end
    end

    def test_increment_expires_in
      @cache.increment "foo", expires_in: 60
      redis_backend do |r|
        assert r.exists?("#{@namespace}:foo")
        assert r.ttl("#{@namespace}:foo") > 0
      end

      # key and ttl exist
      redis_backend { |r| r.setex "#{@namespace}:bar", 120, 1 }
      @cache.increment "bar", expires_in: 60
      redis_backend do |r|
        assert r.ttl("#{@namespace}:bar") > 60
      end

      # key exist but not have expire
      redis_backend(@cache_no_ttl) { |r| r.set "#{@namespace}:dar", 10 }
      @cache_no_ttl.increment "dar", expires_in: 60
      redis_backend(@cache_no_ttl) do |r|
        assert r.ttl("#{@namespace}:dar") > 0
      end
    end

    def test_decrement_ttl
      # existing key
      redis_backend(@cache_no_ttl) { |r| r.set "#{@namespace}:jar", 10 }
      @cache_no_ttl.decrement "jar", 1
      redis_backend(@cache_no_ttl) do |r|
        assert r.get("#{@namespace}:jar").to_i == 9
        assert r.ttl("#{@namespace}:jar") < 0
      end

      # new key
      @cache_no_ttl.decrement "kar", 1
      redis_backend(@cache_no_ttl) do |r|
        assert r.get("#{@namespace}:kar").to_i == -1
        assert r.ttl("#{@namespace}:kar") < 0
      end
    end

    def test_decrement_expires_in
      @cache.decrement "foo", 1, expires_in: 60
      redis_backend do |r|
        assert r.exists?("#{@namespace}:foo")
        assert r.ttl("#{@namespace}:foo") > 0
      end

      # key and ttl exist
      redis_backend { |r| r.setex "#{@namespace}:bar", 120, 1 }
      @cache.decrement "bar", 1, expires_in: 60
      redis_backend do |r|
        assert r.ttl("#{@namespace}:bar") > 60
      end

      # key exist but not have expire
      redis_backend(@cache_no_ttl) { |r| r.set "#{@namespace}:dar", 10 }
      @cache_no_ttl.decrement "dar", 1, expires_in: 60
      redis_backend(@cache_no_ttl) do |r|
        assert r.ttl("#{@namespace}:dar") > 0
      end
    end

    test "fetch caches nil" do
      @cache.write("foo", nil)
      assert_not_called(@cache, :write) do
        assert_nil @cache.fetch("foo") { "baz" }
      end
    end

    test "skip_nil is passed to ActiveSupport::Cache" do
      @cache = lookup_store(skip_nil: true)
      assert_not_called(@cache, :write) do
        assert_nil @cache.fetch("foo") { nil }
        assert_equal false, @cache.exist?("foo")
      end
    end

    def redis_backend(cache = @cache)
      cache.redis.with do |r|
        yield r if block_given?
        return r
      end
    end
  end

  class RedisCacheStoreWithDistributedRedisTest < RedisCacheStoreCommonBehaviorTest
    def lookup_store(options = {})
      super(options.merge(pool: { size: 5 }, url: [ENV["REDIS_URL"] || "redis://localhost:6379/0"] * 2))
    end
  end

  class ConnectionPoolBehaviorTest < StoreTest
    include ConnectionPoolBehavior

    def test_pool_options_work
      cache = ActiveSupport::Cache.lookup_store(:redis_cache_store, pool: { size: 2, timeout: 1 })
      pool = cache.redis # loads 'connection_pool' gem
      assert_kind_of ::ConnectionPool, pool
      assert_equal 2, pool.size
      assert_equal 1, pool.instance_variable_get(:@timeout)
    end

    def test_connection_pooling_by_default
      cache = ActiveSupport::Cache.lookup_store(:redis_cache_store)
      pool = cache.redis
      assert_kind_of ::ConnectionPool, pool
      assert_equal 5, pool.size
      assert_equal 5, pool.instance_variable_get(:@timeout)
    end

    def test_no_connection_pooling_by_default_when_already_a_pool
      redis = ::ConnectionPool.new(size: 10, timeout: 2.5) { Redis.new }
      cache = ActiveSupport::Cache.lookup_store(:redis_cache_store, redis: redis)
      pool = cache.redis
      assert_kind_of ::ConnectionPool, pool
      assert_same redis, pool
      assert_equal 10, pool.size
      assert_equal 2.5, pool.instance_variable_get(:@timeout)
    end

    def test_no_connection_pooling_by_default_when_already_wrapped_in_a_pool
      redis = ::ConnectionPool::Wrapper.new(size: 10, timeout: 2.5) { Redis.new }
      cache = ActiveSupport::Cache.lookup_store(:redis_cache_store, redis: redis)
      wrapped_redis = cache.redis
      assert_kind_of ::Redis, wrapped_redis
      assert_same redis, wrapped_redis
      pool = wrapped_redis.wrapped_pool
      assert_kind_of ::ConnectionPool, pool
      assert_equal 10, pool.size
      assert_equal 2.5, pool.instance_variable_get(:@timeout)
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

  class RedisDistributedConnectionPoolBehaviorTest < ConnectionPoolBehaviorTest
    private
      def store_options
        { url: REDIS_URLS }
      end
  end

  class StoreAPITest < StoreTest
  end

  class UnavailableRedisClient < Redis::Client
    def ensure_connected(...)
      raise Redis::BaseConnectionError
    end
  end

  class MaxClientsReachedRedisClient < Redis::Client
    def ensure_connected(...)
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

        yield ActiveSupport::Cache::RedisCacheStore.new(namespace: @namespace)
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
        timeout: 0.1, namespace: @namespace, expires_in: 60)
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
