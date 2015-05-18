require 'abstract_unit'

module ActionDispatch
  module Routing
    class RouteSetTest < ActiveSupport::TestCase
      class SimpleApp
        def initialize(response)
          @response = response
        end

        def call(env)
          [ 200, { 'Content-Type' => 'text/plain' }, [response] ]
        end
      end

      setup do
        @set = RouteSet.new
      end

      test "not being empty when route is added" do
        assert empty?

        draw do
          get 'foo', to: SimpleApp.new('foo#index')
        end

        assert_not empty?
      end

      test "url helpers are added when route is added" do
        draw do
          get 'foo', to: SimpleApp.new('foo#index')
        end

        assert_equal '/foo', url_helpers.foo_path
        assert_raises NoMethodError do
          assert_equal '/bar', url_helpers.bar_path
        end

        draw do
          get 'foo', to: SimpleApp.new('foo#index')
          get 'bar', to: SimpleApp.new('bar#index')
        end

        assert_equal '/foo', url_helpers.foo_path
        assert_equal '/bar', url_helpers.bar_path
      end

      test "url helpers are updated when route is updated" do
        draw do
          get 'bar', to: SimpleApp.new('bar#index'), as: :bar
        end

        assert_equal '/bar', url_helpers.bar_path

        draw do
          get 'baz', to: SimpleApp.new('baz#index'), as: :bar
        end

        assert_equal '/baz', url_helpers.bar_path
      end

      test "url helpers are removed when route is removed" do
        draw do
          get 'foo', to: SimpleApp.new('foo#index')
          get 'bar', to: SimpleApp.new('bar#index')
        end

        assert_equal '/foo', url_helpers.foo_path
        assert_equal '/bar', url_helpers.bar_path

        draw do
          get 'foo', to: SimpleApp.new('foo#index')
        end

        assert_equal '/foo', url_helpers.foo_path
        assert_raises NoMethodError do
          assert_equal '/bar', url_helpers.bar_path
        end
      end

      test "explicit keys win over implicit keys" do
        draw do
          resources :foo do
            resources :bar, to: SimpleApp.new('foo#show')
          end
        end

        assert_equal '/foo/1/bar/2', url_helpers.foo_bar_path(1, 2)
        assert_equal '/foo/1/bar/2', url_helpers.foo_bar_path(2, foo_id: 1)
      end

      private
        def clear!
          @set.clear!
        end

        def draw(&block)
          @set.draw(&block)
        end

        def url_helpers
          @set.url_helpers
        end

        def empty?
          @set.empty?
        end
    end
  end
end
