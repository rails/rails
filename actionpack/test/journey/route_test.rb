# frozen_string_literal: true

require "abstract_unit"

module ActionDispatch
  module Journey
    class TestRoute < ActiveSupport::TestCase
      def test_initialize
        app      = Object.new
        path     = Path::Pattern.from_string "/:controller(/:action(/:id(.:format)))"
        defaults = {}
        route    = Route.build("name", app, path, {}, [], defaults)

        assert_equal app, route.app
        assert_equal path, route.path
        assert_same  defaults, route.defaults
      end

      def test_route_adds_itself_as_memo
        app      = Object.new
        path     = Path::Pattern.from_string "/:controller(/:action(/:id(.:format)))"
        defaults = {}
        route    = Route.build("name", app, path, {}, [], defaults)

        route.ast.grep(Nodes::Terminal).each do |node|
          assert_equal route, node.memo
        end
      end

      def test_path_requirements_override_defaults
        path = Path::Pattern.build(":name", { name: /love/ }, "/", true)
        defaults  = { name: "tender" }
        route     = Route.build("name", nil, path, {}, [], defaults)
        assert_equal(/love/, route.requirements[:name])
      end

      def test_ip_address
        path  = Path::Pattern.from_string "/messages/:id(.:format)"
        route = Route.build("name", nil, path, { ip: "192.168.1.1" }, [],
                          controller: "foo", action: "bar")
        assert_equal "192.168.1.1", route.ip
      end

      def test_default_ip
        path  = Path::Pattern.from_string "/messages/:id(.:format)"
        route = Route.build("name", nil, path, {}, [],
                          controller: "foo", action: "bar")
        assert_equal(//, route.ip)
      end

      def test_format_with_star
        path  = Path::Pattern.from_string "/:controller/*extra"
        route = Route.build("name", nil, path, {}, [],
                          controller: "foo", action: "bar")
        assert_equal "/foo/himom", route.format(
          controller: "foo",
          extra: "himom")
      end

      def test_connects_all_match
        path  = Path::Pattern.from_string "/:controller(/:action(/:id(.:format)))"
        route = Route.build("name", nil, path, { action: "bar" }, [], controller: "foo")

        assert_equal "/foo/bar/10", route.format(
          controller: "foo",
          action: "bar",
          id: 10)
      end

      def test_extras_are_not_included_if_optional
        path  = Path::Pattern.from_string "/page/:id(/:action)"
        route = Route.build("name", nil, path, {}, [], action: "show")

        assert_equal "/page/10", route.format(id: 10)
      end

      def test_extras_are_not_included_if_optional_with_parameter
        path  = Path::Pattern.from_string "(/sections/:section)/pages/:id"
        route = Route.build("name", nil, path, {}, [], action: "show")

        assert_equal "/pages/10", route.format(id: 10)
      end

      def test_extras_are_not_included_if_optional_parameter_is_nil
        path  = Path::Pattern.from_string "(/sections/:section)/pages/:id"
        route = Route.build("name", nil, path, {}, [], action: "show")

        assert_equal "/pages/10", route.format(id: 10, section: nil)
      end

      def test_score
        constraints = {}
        defaults = { controller: "pages", action: "show" }

        path = Path::Pattern.from_string "/page/:id(/:action)(.:format)"
        specific = Route.build "name", nil, path, constraints, [:controller, :action], defaults

        path = Path::Pattern.from_string "/:controller(/:action(/:id))(.:format)"
        generic = Route.build "name", nil, path, constraints, [], {}

        knowledge = { "id" => true, "controller" => true, "action" => true }

        routes = [specific, generic]

        assert_not_equal specific.score(knowledge), generic.score(knowledge)

        found = routes.sort_by { |r| r.score(knowledge) }.last

        assert_equal specific, found
      end
    end
  end
end
