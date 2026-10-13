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

      def test_clear_clears_the_cached_ast_and_simulator
        mapper.get "/foo(/:id)", to: "foo#bar", as: "aaron"
        simulator = routes.simulator

        routes.clear

        assert_empty routes.ast.children
        assert_not_same simulator, routes.simulator
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

      def test_static_exact_map_includes_static_routes
        mapper.get "/hello", to: "foo#bar"
        mapper.get "/hello/world(.:format)", to: "foo#baz"
        mapper.post "/hello", to: "foo#create"

        assert_equal ["/hello", "/hello/world"], routes.static_exact_map["GET"].keys.sort
        assert_equal ["/hello"], routes.static_exact_map["POST"].keys
        assert_equal "bar", routes.static_exact_map["GET"]["/hello"].defaults[:action]
        assert_equal "create", routes.static_exact_map["POST"]["/hello"].defaults[:action]
      end

      def test_static_exact_map_excludes_dynamic_routes
        mapper.get "/foo/:id", to: "foo#bar"
        mapper.get "/bar/*glob", to: "foo#baz"
        mapper.get "/baz(/:opt)/qux", to: "foo#qux"

        assert_empty routes.static_exact_map
      end

      def test_static_exact_map_excludes_routes_shadowed_by_earlier_routes
        mapper.get "/:slug", to: "foo#slug"
        mapper.get "/hello", to: "foo#bar"
        mapper.get "/hello/world", to: "foo#baz"

        assert_equal ["/hello/world"], routes.static_exact_map["GET"].keys
      end

      def test_static_exact_map_keeps_routes_with_disjoint_verbs
        mapper.post "/:slug", to: "foo#slug"
        mapper.get "/hello", to: "foo#bar"

        assert_equal ["/hello"], routes.static_exact_map["GET"].keys
      end

      def test_static_exact_map_excludes_routes_with_request_constraints
        mapper.get "/hello", to: "foo#bar", constraints: { subdomain: "api" }

        assert_empty routes.static_exact_map
      end

      def test_static_exact_map_excludes_unanchored_routes
        mapper.get "/hello", to: "foo#bar", anchor: false

        assert_empty routes.static_exact_map
      end

      def test_static_exact_map_excludes_routes_shadowed_by_earlier_mounted_apps
        mapper.mount lambda { |env| [200, {}, []] }, at: "/hello"
        mapper.get "/hello/world", to: "foo#baz"
        mapper.get "/other", to: "foo#bar"

        assert_equal ["/other"], routes.static_exact_map["GET"].keys
      end

      def test_static_exact_map_is_built_before_the_routes_are_frozen
        mapper.get "/hello", to: "foo#bar"
        routes.freeze

        assert_equal ["/hello"], routes.static_exact_map["GET"].keys
      end

      def test_static_exact_map_is_rebuilt_when_routes_change
        mapper.get "/hello", to: "foo#bar"
        assert_equal ["/hello"], routes.static_exact_map["GET"].keys

        mapper.get "/world", to: "foo#baz"
        assert_equal ["/hello", "/world"], routes.static_exact_map["GET"].keys.sort
      end
    end
  end
end
