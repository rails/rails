# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/cache"

module ActiveSupport
  module Cache
    module Strategy
      module LocalCache
        class MiddlewareTest < ActiveSupport::TestCase
          class Cache
            include LocalCache
          end

          def test_local_cache_cleared_on_close
            cache = Cache.new
            assert_nil cache.local_cache
            middleware = Middleware.new("<3", cache).new(->(env) {
              assert cache.local_cache, "should have a cache"
              [200, {}, []]
            })
            _, _, body = middleware.call({})
            assert cache.local_cache, "should still have a cache"
            body.each { }
            assert cache.local_cache, "should still have a cache"
            body.close
            assert_nil cache.local_cache
          end

          def test_local_cache_cleared_and_response_should_be_present_on_invalid_parameters_error
            cache = Cache.new
            assert_nil cache.local_cache
            middleware = Middleware.new("<3", cache).new(->(env) {
              assert cache.local_cache, "should have a cache"
              raise Rack::Utils::InvalidParameterError
            })
            response = middleware.call({})
            assert response, "response should exist"
            assert_nil cache.local_cache
          end

          def test_local_cache_cleared_on_exception
            cache = Cache.new
            assert_nil cache.local_cache
            middleware = Middleware.new("<3", cache).new(->(env) {
              assert cache.local_cache, "should have a cache"
              raise
            })
            assert_raises(RuntimeError) { middleware.call({}) }
            assert_nil cache.local_cache
          end

          def test_local_cache_cleared_on_throw
            cache = Cache.new
            assert_nil cache.local_cache
            middleware = Middleware.new("<3", cache).new(->(env) {
              assert cache.local_cache, "should have a cache"
              throw :warden
            })
            assert_throws(:warden) { middleware.call({}) }
            assert_nil cache.local_cache
          end

          def test_local_cache_middlewre_can_reassign_cache
            cache = Cache.new
            new_cache = Cache.new
            middleware = Middleware.new("<3", cache).new(->(env) {
              assert cache.local_cache, "should have a cache"
              throw :warden
            })
            middleware.cache = new_cache

            assert_same(new_cache, middleware.cache)
          end
        end
      end
    end
  end
end
