# frozen_string_literal: true

require "abstract_unit"
require "active_support/cache"
require "active_support/cache/redis_cache_store"
require_relative "../behaviors"

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

    private
      def build(**kwargs)
        ActiveSupport::Cache::RedisCacheStore.new(driver: DRIVER, **kwargs).tap do |cache|
          cache.redis
        end
      end
  end

  class StoreTest < ActiveSupport::TestCase
    setup do
      @namespace = "namespace"

      @cache = ActiveSupport::Cache::RedisCacheStore.new(timeout: 0.1, namespace: @namespace, expires_in: 60, driver: DRIVER)
      # @cache.logger = Logger.new($stdout)  # For test debugging

      # For LocalCacheBehavior tests
      @peek = ActiveSupport::Cache::RedisCacheStore.new(timeout: 0.1, namespace: @namespace, driver: DRIVER)
    end

    teardown do
      @cache.clear
      @cache.redis.disconnect!
    end
  end

  class RedisCacheStoreCommonBehaviorTest < StoreTest
    include CacheStoreBehavior
    include CacheStoreVersionBehavior
    include LocalCacheBehavior
    include CacheIncrementDecrementBehavior
    include AutoloadingCacheBehavior
  end

  # Separate test class so we can omit the namespace which causes expected,
  # appropriate complaints about incompatible string encodings.
  class KeyEncodingSafetyTest < StoreTest
    include EncodedKeyCacheBehavior

    setup do
      @cache = ActiveSupport::Cache::RedisCacheStore.new(timeout: 0.1, driver: DRIVER)
      @cache.logger = nil
    end
  end

  class StoreAPITest < StoreTest
  end

  class UnavailableRedisClient < Redis::Client
    def ensure_connected
      raise Redis::BaseConnectionError
    end
  end

  class FailureSafetyTest < StoreTest
    include FailureSafetyBehavior

    private

      def emulating_unavailability
        old_client = Redis.send(:remove_const, :Client)
        Redis.const_set(:Client, UnavailableRedisClient)

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
      assert !@cache.exist?("foo")
      assert @cache.exist?("fu")
    end

    test "fails with regexp matchers" do
      assert_raise ArgumentError do
        @cache.delete_matched(/OO/i)
      end
    end
  end
end
