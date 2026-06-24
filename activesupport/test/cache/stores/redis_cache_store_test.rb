# frozen_string_literal: true

require_relative "../../abstract_unit"
require "active_support/cache"
require "active_support/cache/redis_cache_store"
require_relative "../behaviors"

module ActiveSupport::Cache::RedisCacheStoreTests
  REDIS_URL = ENV["REDIS_URL"] || "redis://localhost:6379/0"
  REDIS_URLS = ENV["REDIS_URLS"]&.split(",") || %w[ redis://localhost:6379/0 redis://localhost:6379/1 ]

  redis_up = begin
    RedisClient.new(url: REDIS_URL, protocol: 2).call("ping")
    true
  rescue RedisClient::ConnectionError
    false
  end

  REDIS_UP = redis_up || ENV["BUILDKITE"]
  unless REDIS_UP
    $stderr.puts "Skipping redis tests. Start redis and try again."
  end

  class LookupTest < ActiveSupport::TestCase
    test "may be looked up as :redis_cache_store" do
      assert_kind_of ActiveSupport::Cache::RedisCacheStore,
        ActiveSupport::Cache.lookup_store(:redis_cache_store)
    end
  end

  class InitializationTest < ActiveSupport::TestCase
    test "omitted URL uses Redis client with default settings" do
      @cache = ActiveSupport::Cache::RedisCacheStore.new
      assert_equal 1, @cache.redis.connect_timeout
      assert_equal 1, @cache.redis.read_timeout
      assert_equal 1, @cache.redis.write_timeout
      assert_equal "redis://localhost:6379", @cache.redis.config.server_url
    end

    test "no URLs uses Redis client with default settings" do
      @cache = ActiveSupport::Cache::RedisCacheStore.new(url: [])
      assert_equal 1, @cache.redis.connect_timeout
      assert_equal 1, @cache.redis.read_timeout
      assert_equal 1, @cache.redis.write_timeout
      assert_equal "redis://localhost:6379", @cache.redis.config.server_url
    end

    test "singular URL uses Redis client" do
      @cache = ActiveSupport::Cache::RedisCacheStore.new(url: REDIS_URL)
      assert_equal 1, @cache.redis.connect_timeout
      assert_equal 1, @cache.redis.read_timeout
      assert_equal 1, @cache.redis.write_timeout
      assert_equal REDIS_URL.delete_suffix("/0"), @cache.redis.config.server_url
    end

    test "one URL uses Redis client" do
      @cache = ActiveSupport::Cache::RedisCacheStore.new(url: [REDIS_URL])
      assert_equal 1, @cache.redis.connect_timeout
      assert_equal 1, @cache.redis.read_timeout
      assert_equal 1, @cache.redis.write_timeout
      assert_equal REDIS_URL.delete_suffix("/0"), @cache.redis.config.server_url
    end

    test "multiple URLs uses RedisClient::HashRing client" do
      @cache = build url: REDIS_URLS
      assert_kind_of ::RedisClient::HashRing, @cache.redis
      assert_equal REDIS_URLS.size, @cache.redis.nodes.size
      assert_equal REDIS_URLS.map { |u| u.delete_suffix("/0") }, @cache.redis.nodes.map { |n| n.config.server_url }
    end

    test "one :client Config" do
      @cache = ActiveSupport::Cache::RedisCacheStore.new(client: RedisClient.config(url: REDIS_URL))
      assert_equal 1, @cache.redis.connect_timeout
      assert_equal 1, @cache.redis.read_timeout
      assert_equal 1, @cache.redis.write_timeout
      assert_equal REDIS_URL.delete_suffix("/0"), @cache.redis.config.server_url
      assert_kind_of ::RedisClient::Pooled, @cache.redis
    end

    test "one :client callback" do
      @cache = ActiveSupport::Cache::RedisCacheStore.new(client: -> { RedisClient.config(url: REDIS_URL) })
      assert_equal 1, @cache.redis.connect_timeout
      assert_equal 1, @cache.redis.read_timeout
      assert_equal 1, @cache.redis.write_timeout
      assert_equal REDIS_URL.delete_suffix("/0"), @cache.redis.config.server_url
      assert_kind_of ::RedisClient::Pooled, @cache.redis
    end

    test "deprecated :redis argument" do
      @cache = assert_deprecated(/Passing a Redis or ConnectionPool instance/, ActiveSupport.deprecator) do
        ActiveSupport::Cache::RedisCacheStore.new(redis: -> { Redis.new(url: REDIS_URL) })
      end
      assert_kind_of ActiveSupport::Cache::DeprecatedRedisCacheStore, @cache
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
      assert_match(/\A#<ActiveSupport::Cache::RedisCacheStore:0x[0-9a-f]+/, store.inspect)
    end

    private
      def build(**kwargs)
        ActiveSupport::Cache::RedisCacheStore.new(url: REDIS_URL, **kwargs).tap(&:redis)
      end
  end

  class StoreTest < ActiveSupport::TestCase
    module NotificationMiddleware
      def call(command, _redis_config)
        ActiveSupport::Notifications.instrument("redis_query.active_support_test", commands: [command]) { super }
      end

      def call_pipelined(commands, _redis_config)
        ActiveSupport::Notifications.instrument("redis_query.active_support_test", commands: commands) { super }
      end
    end

    setup do
      @cache = nil
      skip "Redis server is not up" unless REDIS_UP
      @namespace = "test-#{SecureRandom.hex}"

      @cache = lookup_store(url: REDIS_URL, expires_in: 60, middlewares: [NotificationMiddleware])
      # @cache.logger = Logger.new($stdout)  # For test debugging

      @cache_no_ttl = lookup_store(url: REDIS_URL)

      # For LocalCacheBehavior tests
      @peek = lookup_store(url: REDIS_URL, expires_in: 60)
    end

    def lookup_store(options = {})
      ActiveSupport::Cache.lookup_store(:redis_cache_store, { url: REDIS_URL, timeout: 0.1, namespace: @namespace, pool: false, error_handler: ->(method:, returning:, exception:) { raise exception } }.merge(options))
    end

    teardown do
      if @cache
        @cache.clear
        @cache.redis.nodes.each(&:close)
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
      commands = capture_redis_commands do
        2.times do
          result = @cache.fetch_multi("a", "b", "c") do |key|
            key * 2
          end
          assert_equal({ "a" => "aa", "b" => "bb", "c" => "cc" }, result)
        end
      end
      assert_includes commands.map(&:first), "mget"
    end

    def test_fetch_multi_with_namespace
      commands = capture_redis_commands do
        result = @cache.fetch_multi("a", "b", "c", namespace: "custom-namespace") do |key|
          key * 2
        end
        assert_equal({ "a" => "aa", "b" => "bb", "c" => "cc" }, result)
      end
      assert_equal ["custom-namespace:a", "custom-namespace:b", "custom-namespace:c"], commands.select { |c| c.shift if c.first == "mget" }.flatten.sort
    end

    def test_write_expires_at
      @cache.write "key_with_expires_at", "bar", expires_at: 30.minutes.from_now
      redis_node_for("#{@namespace}:key_with_expires_at") do |r, k|
        assert r.call("ttl", k) > 0
      end
    end

    def test_write_with_unless_exist
      assert_equal true, @cache.write("foo", 1)
      assert_equal false, @cache.write("foo", 1, unless_exist: true)
    end

    def test_increment_ttl
      # existing key
      redis_node_for("#{@namespace}:jar", @cache_no_ttl) do |r, key|
        r.call("set", key, 10)

        @cache_no_ttl.increment "jar", 1

        assert r.call("get", key).to_i == 11
        assert r.call("ttl", key) < 0
      end

      # new key
      redis_node_for("#{@namespace}:kar", @cache_no_ttl) do |r, new_key|
        @cache_no_ttl.increment "kar", 1

        assert r.call("get", new_key).to_i == 1
        assert r.call("ttl", new_key) < 0
      end
    end

    def test_increment_expires_in
      @cache.increment "foo", expires_in: 60
      redis_node_for("#{@namespace}:foo") do |r, key|
        assert_equal 1, r.call("exists", key)
        assert r.call("ttl", key) > 0
      end

      # key and ttl exist
      redis_node_for("#{@namespace}:bar") do |r, key|
        r.call("setex", key, 120, 1)

        @cache.increment "bar", expires_in: 60

        assert r.call("ttl", key) > 60
      end

      # key exist but not have expire
      redis_node_for("#{@namespace}:dar", @cache_no_ttl) do |r, key|
        r.call("set", key, 10)

        @cache_no_ttl.increment "dar", expires_in: 60

        assert r.call("ttl", key) > 0
      end
    end

    def test_decrement_ttl
      # existing key
      redis_node_for("#{@namespace}:jar", @cache_no_ttl) do |r, key|
        r.call("set", key, 10)

        @cache_no_ttl.decrement "jar", 1

        assert r.call("get", key).to_i == 9
        assert r.call("ttl", key) < 0
      end

      # new key
      redis_node_for("#{@namespace}:kar", @cache_no_ttl) do |r, key|
        @cache_no_ttl.decrement "kar", 1

        assert r.call("get", key).to_i == -1
        assert r.call("ttl", key) < 0
      end
    end

    def test_decrement_expires_in
      @cache.decrement "foo", 1, expires_in: 60

      redis_node_for("#{@namespace}:foo") do |r, key|
        assert_equal 1, r.call("exists", key)
        assert r.call("ttl", key) > 0
      end

      # key and ttl exist
      redis_node_for("#{@namespace}:bar") do |r, key|
        r.call "setex", key, 120, 1

        @cache.decrement "bar", 1, expires_in: 60

        assert r.call("ttl", "#{@namespace}:bar") > 60
      end

      # key exist but not have expire
      redis_node_for("#{@namespace}:dar", @cache_no_ttl) do |r, key|
        r.call "set", "#{@namespace}:dar", 10

        @cache_no_ttl.decrement "dar", 1, expires_in: 60

        assert r.call("ttl", "#{@namespace}:dar") > 0
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

    def redis_node_for(key, cache = @cache)
      cache.redis.node_for(key).with do |c|
        yield c, key
      end
    end

    def capture_redis_commands(&block)
      capture_notifications("redis_query.active_support_test", &block).flat_map { |e| e.payload.fetch(:commands) }
    end
  end

  class RedisCacheStoreWithDistributedRedisTest < RedisCacheStoreCommonBehaviorTest
    def lookup_store(options = {})
      url = URI(ENV["REDIS_URL"] || "redis://localhost:6379/0")
      urls = [
        url.dup.tap { |u| u.path = "/1" },
        url.dup.tap { |u| u.path = "/2" },
      ]

      super(options.merge(pool: { size: 5 }, url: urls))
    end
  end

  class ConnectionPoolBehaviorTest < StoreTest
    include ConnectionPoolBehavior

    def test_pool_options_work
      cache = ActiveSupport::Cache.lookup_store(:redis_cache_store, pool: { size: 2, timeout: 1 })
      assert_kind_of ::RedisClient::Pooled, cache.redis
      assert_equal 2, cache.redis.size
    end

    private
      def store
        [:redis_cache_store]
      end

      def emulating_latency(&block)
        callback = ->(event) do
          if event.payload[:commands].any? { |c| c.first.downcase == "get" && c.second.match?(/latency/) }
            sleep 0.2
          end
        end
        ActiveSupport::Notifications.subscribed(callback, "redis_query.active_support_test", &block)
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

  module UnavailableRedisMiddleware
    def call(...)
      raise ::RedisClient::ConnectionError
    end

    def call_pipelined(...)
      raise ::RedisClient::ConnectionError
    end
  end

  module MaxClientsReachedRedisMiddleware
    def call(...)
      raise ::RedisClient::CannotConnectError
    end

    def call_pipelined(...)
      raise ::RedisClient::CannotConnectError
    end
  end

  class FailureRaisingFromUnavailableClientTest < StoreTest
    include FailureRaisingBehavior

    private
      def assert_raise_redis_error(...)
        assert_raise(RedisClient::ConnectionError, ...)
      end

      def emulating_unavailability
        yield ActiveSupport::Cache::RedisCacheStore.new(
          namespace: @namespace,
          middlewares: [UnavailableRedisMiddleware],
          error_handler: -> (method:, returning:, exception:) { raise exception },
        )
      end
  end

  class FailureRaisingFromMaxClientsReachedErrorTest < StoreTest
    include FailureRaisingBehavior

    private
      def assert_raise_redis_error(...)
        assert_raise(RedisClient::ConnectionError, ...)
      end

      def emulating_unavailability
        yield ActiveSupport::Cache::RedisCacheStore.new(
          namespace: @namespace,
          middlewares: [MaxClientsReachedRedisMiddleware],
          error_handler: -> (method:, returning:, exception:) { raise exception },
        )
      end
  end

  class FailureSafetyFromUnavailableClientTest < StoreTest
    include FailureSafetyBehavior

    private
      def emulating_unavailability
        yield ActiveSupport::Cache::RedisCacheStore.new(
          namespace: @namespace,
          middlewares: [UnavailableRedisMiddleware],
        )
      end
  end

  class FailureSafetyFromMaxClientsReachedErrorTest < StoreTest
    include FailureSafetyBehavior

    private
      def emulating_unavailability
        yield ActiveSupport::Cache::RedisCacheStore.new(
          namespace: @namespace,
          middlewares: [MaxClientsReachedRedisMiddleware],
        )
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
      @cache.redis.node_for(other_key).call("set", other_key, SecureRandom.alphanumeric)
      @cache.clear

      assert_not @cache.exist?(key)
      r = @cache.redis.node_for(other_key)
      assert_equal 1, r.call("exists", other_key)
      r.call("del", other_key)
    end

    test "clear all cache key with RedisClient::HashRing" do
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
        assert_equal 0, r.call("exists", "#{@namespace}:foo")
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
        @cache.send(:bypass_local_cache) { @cache.write("foo", "baz") }
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
