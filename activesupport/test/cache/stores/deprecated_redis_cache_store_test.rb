# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require "active_support/cache/deprecated_redis_cache_store"
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

module ActiveSupport::Cache::DeprecatedRedisCacheStoreTests
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
    test "may be looked up as :deprecated_redis_cache_store" do
      assert_kind_of ActiveSupport::Cache::DeprecatedRedisCacheStore,
        ActiveSupport::Cache.lookup_store(:deprecated_redis_cache_store)
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

    test "inspect shows options and redis" do
      store = build(url: REDIS_URL)

      assert_match(/@options=/, store.inspect)
      assert_match(/@redis=/, store.inspect)
      assert_match(/\A#<ActiveSupport::Cache::DeprecatedRedisCacheStore:0x[0-9a-f]+/, store.inspect)
    end

    private
      def build(**kwargs)
        ActiveSupport::Cache::DeprecatedRedisCacheStore.new(pool: false, **kwargs).tap(&:redis)
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
      ActiveSupport::Cache.lookup_store(:deprecated_redis_cache_store, { timeout: 0.1, namespace: @namespace, pool: false }.merge(options))
    end

    teardown do
      @cache.clear
      @cache.redis.with do |r|
        r.respond_to?(:on_each_node, true) ? r.send(:on_each_node, :disconnect!) : r.disconnect!
      end
    end
  end

  class DeprecatedRedisCacheStoreCommonBehaviorTest < StoreTest
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

  class DeprecatedRedisCacheStoreWithDistributedRedisTest < DeprecatedRedisCacheStoreCommonBehaviorTest
    def lookup_store(options = {})
      super(options.merge(pool: { size: 5 }, url: [ENV["REDIS_URL"] || "redis://localhost:6379/0"] * 2))
    end
  end

  class ConnectionPoolBehaviorTest < StoreTest
    include ConnectionPoolBehavior

    class GenericRedisPool
      class Error < RuntimeError; end
      class TimeoutError < Timeout::Error; end

      attr_writer :error

      def initialize(connection)
        @connection = connection
      end

      def with(**)
        raise @error if @error

        yield @connection
      end

      def checkout(**)
        raise @error if @error

        @connection
      end

      def checkin(*)
      end
    end

    class GenericRedisPoolWrapper
      def initialize(pool)
        @pool = pool
      end

      def wrapped_pool
        @pool
      end

      def with(**, &block)
        @pool.with(**, &block)
      end
    end

    def test_pool_exhaustion_returns_a_miss_and_recovers
      cache = ActiveSupport::Cache::DeprecatedRedisCacheStore.new(
        namespace: @namespace,
        pool: { size: 1, timeout: 0 },
      )
      cache.write("pool-key", "pool-value")
      pool = cache.redis
      ready = Queue.new
      release = Queue.new

      holder = Thread.new do
        pool.with do
          ready << true
          release.pop
        end
      end

      ready.pop
      assert_nil cache.read("pool-key")
      release << true
      holder.join
      assert_equal "pool-value", cache.read("pool-key")
    ensure
      release << true if release && holder&.alive?
      holder&.join
      pool&.shutdown(&:close)
    end

    def test_adapts_a_noninternal_pool
      connection = Redis.new(url: REDIS_URL)
      pool = GenericRedisPool.new(connection)
      errors = []
      cache = supplied_pool_store(pool, error_handler: -> (method:, returning:, exception:) { errors << exception })

      cache.write("pool-key", "pool-value")
      assert_equal "pool-value", cache.read("pool-key")

      pool.error = GenericRedisPool::TimeoutError.new
      assert_nil cache.read("pool-key")
      assert_instance_of GenericRedisPool::TimeoutError, errors.last
    ensure
      connection&.close
    end

    def test_adapts_a_noninternal_pool_wrapper
      connection = Redis.new(url: REDIS_URL)
      wrapper = GenericRedisPoolWrapper.new(GenericRedisPool.new(connection))
      cache = supplied_pool_store(wrapper)

      cache.write("pool-key", "pool-value")
      assert_equal "pool-value", cache.read("pool-key")
    ensure
      connection&.close
    end

    def test_supplied_internal_pool_preserves_identity_and_cache_behavior
      pool = ActiveSupport::ConnectionPool.new { Redis.new(url: REDIS_URL) }

      assert_supplied_pool_round_trip(pool)
    end

    def test_supplied_internal_pool_errors_preserve_cache_failure_behavior
      errors = []
      pool = ActiveSupport::ConnectionPool.new(size: 1, timeout: 0) { Redis.new(url: REDIS_URL) }
      cache = supplied_pool_store(pool, error_handler: -> (method:, returning:, exception:) { errors << exception })
      cache.write("pool-key", "pool-value")
      ready = Queue.new
      release = Queue.new

      holder = Thread.new do
        pool.with do
          ready << true
          release.pop
        end
      end

      ready.pop
      assert_nil cache.read("pool-key")
      assert_instance_of ActiveSupport::ConnectionPool::TimeoutError, errors.last
      release << true
      holder.join
      pool.shutdown(&:close)

      assert_nil cache.read("pool-key")
      assert_instance_of ActiveSupport::ConnectionPool::PoolShuttingDownError, errors.last

      raising_pool = ActiveSupport::ConnectionPool.new(size: 1, timeout: 0) { Redis.new(url: REDIS_URL) }
      raising_cache = supplied_pool_store(raising_pool, error_handler: -> (method:, returning:, exception:) { raise exception })
      raising_ready = Queue.new
      raising_release = Queue.new
      raising_holder = Thread.new do
        raising_pool.with do
          raising_ready << true
          raising_release.pop
        end
      end

      raising_ready.pop
      assert_raises(ActiveSupport::ConnectionPool::TimeoutError) { raising_cache.read("pool-key") }
    ensure
      release << true if release && holder&.alive?
      holder&.join
      pool&.shutdown(&:close)
      raising_release << true if defined?(raising_release) && raising_holder&.alive?
      raising_holder&.join if defined?(raising_holder)
      raising_pool&.shutdown(&:close) if defined?(raising_pool)
    end

    private
      def assert_supplied_pool_round_trip(pool)
        cache = supplied_pool_store(pool)

        assert_same pool, cache.redis
        cache.write("pool-key", "pool-value")
        assert_equal "pool-value", cache.read("pool-key")
      ensure
        pool&.shutdown(&:close)
      end

      def supplied_pool_store(pool, error_handler: nil)
        options = { namespace: @namespace, redis: pool }
        options[:error_handler] = error_handler if error_handler
        ActiveSupport::Cache::DeprecatedRedisCacheStore.new(**options)
      end

      def store
        [:deprecated_redis_cache_store]
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

  class RedisClientErrorRedisClient < Redis::Client
    def ensure_connected(...)
      raise RedisClient::Error
    end

    def self.translate_error!(error, **)
      raise error
    end
  end

  class FailureRaisingFromUnavailableClientTest < StoreTest
    include FailureRaisingBehavior

    private
      def assert_raise_redis_error(...)
        assert_raise(Redis::BaseError, ...)
      end

      def emulating_unavailability
        old_client = Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, UnavailableRedisClient)

        yield ActiveSupport::Cache::DeprecatedRedisCacheStore.new(namespace: @namespace,
                                                        error_handler: -> (method:, returning:, exception:) { raise exception })
      ensure
        Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, old_client)
      end
  end

  class FailureRaisingFromMaxClientsReachedErrorTest < StoreTest
    include FailureRaisingBehavior

    private
      def assert_raise_redis_error(...)
        assert_raise(Redis::BaseError, ...)
      end

      def emulating_unavailability
        old_client = Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, MaxClientsReachedRedisClient)

        yield ActiveSupport::Cache::DeprecatedRedisCacheStore.new(
          namespace: @namespace,
          error_handler: -> (method:, returning:, exception:) { raise exception }
        )
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

        yield ActiveSupport::Cache::DeprecatedRedisCacheStore.new(namespace: @namespace)
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

        yield ActiveSupport::Cache::DeprecatedRedisCacheStore.new(namespace: @namespace)
      ensure
        Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, old_client)
      end
  end

  class FailureSafetyFromRedisClientErrorTest < StoreTest
    include FailureSafetyBehavior

    private
      def emulating_unavailability
        old_client = Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, RedisClientErrorRedisClient)

        yield ActiveSupport::Cache::DeprecatedRedisCacheStore.new(namespace: @namespace)
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
      cache = ActiveSupport::Cache::DeprecatedRedisCacheStore.new(
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

  class ReadDeleteTest < StoreTest
    test "read with delete: true returns the value and removes the key" do
      @cache.write("foo", "bar")
      assert_equal "bar", @cache.read("foo", delete: true)
      assert_nil @cache.read("foo")
    end

    test "read with delete: true returns nil for missing key" do
      assert_nil @cache.read("missing", delete: true)
    end

    test "read with delete: true removes the key from redis" do
      @cache.write("foo", "bar")
      @cache.read("foo", delete: true)
      redis_backend do |r|
        assert_not r.exists?("#{@namespace}:foo")
      end
    end

    test "read with delete: true works with raw values" do
      @cache.write("foo", "bar", raw: true)
      assert_equal "bar", @cache.read("foo", raw: true, delete: true)
      assert_nil @cache.read("foo", raw: true)
    end

    test "read without delete option still works normally" do
      @cache.write("foo", "bar")
      assert_equal "bar", @cache.read("foo")
      assert_equal "bar", @cache.read("foo")
    end

    test "read with delete: true on expired entry returns nil" do
      @cache.write("foo", "bar", expires_in: 1)
      travel(2.seconds) do
        assert_nil @cache.read("foo", delete: true)
      end
    end

    test "read with delete: true returns value and clears local cache" do
      @cache.with_local_cache do
        @cache.write("foo", "bar")
        assert_equal "bar", @cache.read("foo", delete: true)
        assert_nil @cache.read("foo")
      end
    end

    test "read with delete: true clears remote cache within local cache scope" do
      @cache.with_local_cache do
        @cache.write("foo", "bar")
        assert_equal "bar", @cache.read("foo", delete: true)
      end
      # After local cache scope ends, remote should also be gone
      assert_nil @cache.read("foo")
    end

    test "read with delete: true bypasses stale local cache" do
      @cache.with_local_cache do
        @cache.write("foo", "bar")
        # Overwrite in remote behind local cache's back
        @cache.send(:use_temporary_local_cache, nil) { @cache.write("foo", "baz") }
        # Without delete, local cache returns stale value
        assert_equal "bar", @cache.read("foo")
        # With delete, it should bypass local cache and hit remote
        assert_equal "baz", @cache.read("foo", delete: true)
        # Both local and remote should be cleared
        assert_nil @cache.read("foo")
      end
    end

    def redis_backend(cache = @cache)
      cache.redis.with do |r|
        yield r if block_given?
        return r
      end
    end
  end
end
