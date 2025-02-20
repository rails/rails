# frozen_string_literal: true

require "active_support/testing/strict_warnings"
require "active_support"
require "active_support/testing/autorun"
require "rails/configuration"
require "active_support/test_case"
require "minitest/mock"

module Rails
  module Configuration
    class MiddlewareStackProxyTest < ActiveSupport::TestCase
      class FooMiddleware; end
      class BarMiddleware; end
      class BazMiddleware; end
      class HiyaMiddleware; end

      class TestMiddlewareStack
        attr_accessor :middlewares

        def initialize
          @middlewares = []
        end

        def nested_stack
          self.class.new
        end

        def use(middleware)
          @middlewares << middleware
        end

        def insert_before(other_middleware, middleware)
          i = middlewares.index(other_middleware)
          raise "No such middleware to insert_before: #{other_middleware}" unless i
          middlewares.insert(i, middleware)
        end
      end

      def setup
        @stack = MiddlewareStackProxy.new
      end

      def test_playback_insert_before
        @stack.insert_before :foo
        assert_playback :insert_before, :foo
      end

      def test_playback_insert
        @stack.insert :foo
        assert_playback :insert_before, :foo
      end

      def test_playback_insert_after
        @stack.insert_after :foo
        assert_playback :insert_after, :foo
      end

      def test_playback_swap
        @stack.swap :foo
        assert_playback :swap, :foo
      end

      def test_playback_use
        @stack.use :foo
        assert_playback :use, :foo
      end

      def test_playback_delete
        @stack.delete :foo
        assert_playback :delete, :foo
      end

      def test_playback_move_before
        @stack.move_before :foo
        assert_playback :move_before, :foo
      end

      def test_playback_move
        @stack.move :foo
        assert_playback :move_before, :foo
      end

      def test_playback_move_after
        @stack.move_after :foo
        assert_playback :move_after, :foo
      end

      def test_order
        @stack.swap :foo
        @stack.delete :foo

        assert_playback([:swap, :delete], :foo)
      end

      def test_create_nested_stack_proxy
        root_proxy = MiddlewareStackProxy.new
        nested_proxy = root_proxy.create_stack

        assert_not_equal root_proxy, nested_proxy
        assert nested_proxy.is_a?(MiddlewareStackProxy)
      end

      def test_nested_stack_proxies
        root_proxy = MiddlewareStackProxy.new
        root_proxy.use FooMiddleware
        root_proxy.use BarMiddleware
        outer_nested_proxy = root_proxy.create_stack
        inner_nested_proxy = root_proxy.create_stack
        outer_nested_proxy.use BazMiddleware
        outer_nested_proxy.use inner_nested_proxy
        inner_nested_proxy.use HiyaMiddleware
        root_proxy.insert_before BarMiddleware, outer_nested_proxy

        root_merged = root_proxy.merge_into(TestMiddlewareStack.new)
        assert_equal [FooMiddleware, outer_nested_proxy, BarMiddleware], root_merged.middlewares
        outer_merged = outer_nested_proxy.merge_into(TestMiddlewareStack.new)
        assert_equal [BazMiddleware, inner_nested_proxy], outer_merged.middlewares
      end

      private
        def assert_playback(msg_names, args)
          self.assertions += 1
          mock = Minitest::Mock.new
          Array(msg_names).each do |msg_name|
            mock.expect msg_name, nil, [args]
          end
          @stack.merge_into(mock)
          mock.verify
        end
    end
  end
end
