# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Journey
    class TestRoutes < ActiveSupport::TestCase
      attr_reader :routes, :mapper

      def setup
        @route_set = ActionDispatch::Routing::RouteSet.new
        @routes = @route_set.router.routes
        @router = @route_set.router
        @mapper = ActionDispatch::Routing::Mapper.new @route_set
        super
      end

      def test_clear
        mapper.get "/foo(/:id)", to: "foo#bar", as: "aaron"
        assert_not_empty routes
        assert_equal 1, routes.length

        routes.clear
        assert_empty routes
        assert_equal 0, routes.length
      end

      def test_ast
        mapper.get "/foo(/:id)", to: "foo#bar", as: "aaron"
        ast = routes.ast
        mapper.get "/foo(/:id)", to: "foo#bar", as: "gorby"
        assert_not_equal ast, routes.ast
      end

      def test_simulator_changes
        mapper.get "/foo(/:id)", to: "foo#bar", as: "aaron"
        sim = routes.simulator
        mapper.get "/foo(/:id)", to: "foo#bar", as: "gorby"
        assert_not_equal sim, routes.simulator
      end

      def test_partition_route
        mapper.get "/foo(/:id)", to: "foo#bar", as: "aaron"

        assert_equal 1, @routes.anchored_routes.length
        assert_empty @routes.custom_routes

        mapper.get "/not_anchored/hello/:who-notanchored", to: "foo#bar", as: "bar", who: /\d/, anchor: false

        assert_equal 1, @routes.custom_routes.length
        assert_equal 1, @routes.anchored_routes.length
      end

      def test_custom_anchored_not_partition_route
        mapper.get "/foo/:bar", to: "foo#bar", as: "aaron"

        assert_equal 1, @routes.anchored_routes.length
        assert_empty @routes.custom_routes

        mapper.get "/:user/:repo", to: "foo#bar", as: "bar", repo: /[\w.]+/

        assert_equal 2, @routes.anchored_routes.length
        assert_empty @routes.custom_routes
      end

      def test_first_name_wins
        mapper.get "/hello", to: "foo#bar", as: "aaron"
        assert_raise(ArgumentError) do
          mapper.get "/aaron", to: "foo#bar", as: "aaron"
        end
      end
    end
  end
end
