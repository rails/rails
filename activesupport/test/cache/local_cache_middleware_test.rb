# frozen_string_literal: true

require_relative "../abstract_unit"
require "active_support/cache"

module ActiveSupport
  module Cache
    module Strategy
      module LocalCache
        class MiddlewareTest < ActiveSupport::TestCase
          def test_local_cache_cleared_on_close
            key = "super awesome key"
            assert_nil LocalCacheRegistry.cache_for key
            middleware = Middleware.new("<3", key).new(->(env) {
              assert LocalCacheRegistry.cache_for(key), "should have a cache"
              [200, {}, []]
            })
            _, _, body = middleware.call({})
            assert LocalCacheRegistry.cache_for(key), "should still have a cache"
            body.each { }
            assert LocalCacheRegistry.cache_for(key), "should still have a cache"
            body.close
            assert_nil LocalCacheRegistry.cache_for(key)
          end

          def test_local_cache_cleared_and_response_should_be_present_on_invalid_parameters_error
            key = "super awesome key"
            assert_nil LocalCacheRegistry.cache_for key
            middleware = Middleware.new("<3", key).new(->(env) {
              assert LocalCacheRegistry.cache_for(key), "should have a cache"
              raise Rack::Utils::InvalidParameterError
            })
            response = middleware.call({})
            assert response, "response should exist"
            assert_nil LocalCacheRegistry.cache_for(key)
          end

          def test_local_cache_cleared_on_exception
            key = "super awesome key"
            assert_nil LocalCacheRegistry.cache_for key
            middleware = Middleware.new("<3", key).new(->(env) {
              assert LocalCacheRegistry.cache_for(key), "should have a cache"
              raise
            })
            assert_raises(RuntimeError) { middleware.call({}) }
            assert_nil LocalCacheRegistry.cache_for(key)
          end

          def test_local_cache_cleared_on_throw
            key = "super awesome key"
            assert_nil LocalCacheRegistry.cache_for key
            middleware = Middleware.new("<3", key).new(->(env) {
              assert LocalCacheRegistry.cache_for(key), "should have a cache"
              throw :warden
            })
            assert_throws(:warden) { middleware.call({}) }
            assert_nil LocalCacheRegistry.cache_for(key)
          end

          def test_local_cache_not_cleared_on_close_when_clear_cache_is_false
            key = "super awesome key"
            assert_nil LocalCacheRegistry.cache_for key
            middleware = Middleware.new("<3", key).new(->(env) {
              assert LocalCacheRegistry.cache_for(key), "should have a cache"
              [200, {}, []]
            })
            _, _, body = middleware.call({})
            assert LocalCacheRegistry.cache_for(key), "should still have a cache"
            body.each { }
            assert LocalCacheRegistry.cache_for(key), "should still have a cache"

            clear_cache = middleware.clear_cache?
            middleware.clear_cache = false
            body.close
            assert LocalCacheRegistry.cache_for(key), "should still have a cache"
          ensure
            LocalCacheRegistry.set_cache_for(key, nil)
            middleware.clear_cache = clear_cache
          end

          def test_local_cache_no_cleared_on_exception_when_clear_cache_is_false
            key = "super awesome key"
            assert_nil LocalCacheRegistry.cache_for key
            middleware = Middleware.new("<3", key).new(->(env) {
              assert LocalCacheRegistry.cache_for(key), "should have a cache"
              raise
            })
            clear_cache = middleware.clear_cache?
            middleware.clear_cache = false
            assert_raises(RuntimeError) { middleware.call({}) }
            assert LocalCacheRegistry.cache_for(key), "should still have a cache"
          ensure
            LocalCacheRegistry.set_cache_for(key, nil)
            middleware.clear_cache = clear_cache
          end
        end
      end
    end
  end
end
