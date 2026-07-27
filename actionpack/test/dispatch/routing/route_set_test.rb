# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/object/with"

module ActionDispatch
  module Routing
    class RouteSetTest < ActiveSupport::TestCase
      class SimpleApp
        def initialize(response)
          @response = response
        end

        def call(env)
          [ 200, { "Content-Type" => "text/plain" }, [response] ]
        end
      end

      setup do
        @set = RouteSet.new
      end

      test "not being empty when route is added" do
        assert_empty @set

        draw do
          get "foo", to: SimpleApp.new("foo#index")
        end

        assert_not_empty @set
      end

      class FooController < ActionController::Base
      end

      test "recognize_path does not recognize routes removed by a redraw" do
        controller = "action_dispatch/routing/route_set_test/foo"

        draw do
          get "foo", to: "action_dispatch/routing/route_set_test/foo#index"
        end

        assert_equal({ controller: controller, action: "index" }, @set.recognize_path("/foo"))

        draw { }

        assert_raises ActionController::RoutingError do
          @set.recognize_path("/foo")
        end
      end

      test "URL helpers are added when route is added" do
        draw do
          get "foo", to: SimpleApp.new("foo#index")
        end

        assert_equal "/foo", url_helpers.foo_path
        assert_raises NoMethodError do
          url_helpers.bar_path
        end

        draw do
          get "foo", to: SimpleApp.new("foo#index")
          get "bar", to: SimpleApp.new("bar#index")
        end

        assert_equal "/foo", url_helpers.foo_path
        assert_equal "/bar", url_helpers.bar_path
      end

      test "URL helpers are updated when route is updated" do
        draw do
          get "bar", to: SimpleApp.new("bar#index"), as: :bar
        end

        assert_equal "/bar", url_helpers.bar_path

        draw do
          get "baz", to: SimpleApp.new("baz#index"), as: :bar
        end

        assert_equal "/baz", url_helpers.bar_path
      end

      test "URL helpers are removed when route is removed" do
        draw do
          get "foo", to: SimpleApp.new("foo#index")
          get "bar", to: SimpleApp.new("bar#index")
        end

        assert_equal "/foo", url_helpers.foo_path
        assert_equal "/bar", url_helpers.bar_path

        draw do
          get "foo", to: SimpleApp.new("foo#index")
        end

        assert_equal "/foo", url_helpers.foo_path
        assert_raises NoMethodError do
          url_helpers.bar_path
        end
      end

      test "only_path: true with *_url and no :host option" do
        draw do
          get "foo", to: SimpleApp.new("foo#index")
        end

        assert_equal "/foo", url_helpers.foo_url(only_path: true)
      end

      test "only_path: false with *_url and no :host option" do
        draw do
          get "foo", to: SimpleApp.new("foo#index")
        end

        assert_raises ArgumentError do
          url_helpers.foo_url(only_path: false)
        end
      end

      test "only_path: false with *_url and local :host option" do
        draw do
          get "foo", to: SimpleApp.new("foo#index")
        end

        assert_equal "http://example.com/foo", url_helpers.foo_url(only_path: false, host: "example.com")
      end

      test "only_path: false with *_url and global :host option" do
        @set.default_url_options = { host: "example.com" }

        draw do
          get "foo", to: SimpleApp.new("foo#index")
        end

        assert_equal "http://example.com/foo", url_helpers.foo_url(only_path: false)
      end

      test "explicit keys win over implicit keys" do
        draw do
          resources :foo do
            resources :bar, to: SimpleApp.new("foo#show")
          end
        end

        assert_equal "/foo/1/bar/2", url_helpers.foo_bar_path(1, 2)
        assert_equal "/foo/1/bar/2", url_helpers.foo_bar_path(2, foo_id: 1)
      end

      test "having an optional scope with resources" do
        draw do
          scope "(/:foo)" do
            resources :users
          end
        end

        assert_equal "/users/1", url_helpers.user_path(1)
        assert_equal "/users/1", url_helpers.user_path(1, foo: nil)
        assert_equal "/a/users/1", url_helpers.user_path(1, foo: "a")
      end

      test "implicit path components consistently return the same result" do
        draw do
          resources :users, to: SimpleApp.new("foo#index")
        end
        assert_equal "/users/1.json", url_helpers.user_path(1, :json)
        assert_equal "/users/1.json", url_helpers.user_path(1, format: :json)
        assert_equal "/users/1.json", url_helpers.user_path(1, :json)
      end

      test "escape new line for dynamic params" do
        draw do
          get "/dynamic/:dynamic_segment", to: SimpleApp.new("foo#index"), as: :dynamic
        end

        assert_equal "/dynamic/a%0Anewline", url_helpers.dynamic_path(dynamic_segment: "a\nnewline")
      end

      test "escape new line for wildcard params" do
        draw do
          get "/wildcard/*wildcard_segment", to: SimpleApp.new("foo#index"), as: :wildcard
        end

        assert_equal "/wildcard/a%0Anewline", url_helpers.wildcard_path(wildcard_segment: "a\nnewline")
      end

      test "find a route for the given requirements" do
        draw do
          resources :foo
          resources :bar
        end

        route = @set.from_requirements(controller: "bar", action: "index")

        assert_equal "bar_index", route.name
      end

      test "find a route for the given requirements returns nil for no match" do
        draw do
          resources :foo
          resources :bar
        end

        route = @set.from_requirements(controller: "baz", action: "index")

        assert_nil route
      end

      if RUBY_VERSION >= "4.0"
        test "#resolve raises an error when a proc is not shareable and unshareable_proc_action is :raise" do
          assert_raise(Ractor::IsolationError) do
            ActiveSupport::Ractors.with(unshareable_proc_action: :raise) do
              draw do
                to_resolve = [:basket, anchor: "items"]

                resolve("Cart") { to_resolve }
              end
            end
          end
        end

        test "#resolve trigger a deprecation when a proc is not shareable and unshareable_proc_action is :warn" do
          assert_deprecated(/Rails attempted to make a Proc .* Ractor shareable/, ActiveSupport.deprecator) do
            ActiveSupport::Ractors.with(unshareable_proc_action: :warn) do
              draw do
                to_resolve = [:basket, anchor: "items"]

                resolve("Cart") { to_resolve }
              end
            end
          end
        end

        test "#resolve does not attempt to make a proc shareable when unshareable_proc_action is nil" do
          assert_nothing_raised do
            ActiveSupport::Ractors.with(unshareable_proc_action: nil) do
              draw do
                to_resolve = [:basket, anchor: "items"]

                resolve("Cart") { to_resolve }
              end
            end
          end
        end
      end

      private
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
