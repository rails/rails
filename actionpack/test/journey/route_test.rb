require 'abstract_unit'

module ActionDispatch
  module Journey
    class TestRoute < ActiveSupport::TestCase
      def test_initialize
        app      = Object.new
        path     = Path::Pattern.new '/:controller(/:action(/:id(.:format)))'
        defaults = {}
        route    = Route.new("name", app, path, {}, defaults)

        assert_equal app, route.app
        assert_equal path, route.path
        assert_same  defaults, route.defaults
      end

      def test_route_adds_itself_as_memo
        app      = Object.new
        path     = Path::Pattern.new '/:controller(/:action(/:id(.:format)))'
        defaults = {}
        route    = Route.new("name", app, path, {}, defaults)

        route.ast.grep(Nodes::Terminal).each do |node|
          assert_equal route, node.memo
        end
      end

      def test_ip_address
        path  = Path::Pattern.new '/messages/:id(.:format)'
        route = Route.new("name", nil, path, {:ip => '192.168.1.1'},
                          { :controller => 'foo', :action => 'bar' })
        assert_equal '192.168.1.1', route.ip
      end

      def test_default_ip
        path  = Path::Pattern.new '/messages/:id(.:format)'
        route = Route.new("name", nil, path, {},
                          { :controller => 'foo', :action => 'bar' })
        assert_equal(//, route.ip)
      end

      def test_format_with_star
        path  = Path::Pattern.new '/:controller/*extra'
        route = Route.new("name", nil, path, {},
                          { :controller => 'foo', :action => 'bar' })
        assert_equal '/foo/himom', route.format({
          :controller => 'foo',
          :extra      => 'himom',
        })
      end

      def test_connects_all_match
        path  = Path::Pattern.new '/:controller(/:action(/:id(.:format)))'
        route = Route.new("name", nil, path, {:action => 'bar'}, { :controller => 'foo' })

        assert_equal '/foo/bar/10', route.format({
          :controller => 'foo',
          :action     => 'bar',
          :id         => 10
        })
      end

      def test_extras_are_not_included_if_optional
        path  = Path::Pattern.new '/page/:id(/:action)'
        route = Route.new("name", nil, path, { }, { :action => 'show' })

        assert_equal '/page/10', route.format({ :id => 10 })
      end

      def test_extras_are_not_included_if_optional_with_parameter
        path  = Path::Pattern.new '(/sections/:section)/pages/:id'
        route = Route.new("name", nil, path, { }, { :action => 'show' })

        assert_equal '/pages/10', route.format({:id => 10})
      end

      def test_extras_are_not_included_if_optional_parameter_is_nil
        path  = Path::Pattern.new '(/sections/:section)/pages/:id'
        route = Route.new("name", nil, path, { }, { :action => 'show' })

        assert_equal '/pages/10', route.format({:id => 10, :section => nil})
      end

      def test_score
        constraints = {:required_defaults => [:controller, :action]}
        defaults = {:controller=>"pages", :action=>"show"}

        path = Path::Pattern.new "/page/:id(/:action)(.:format)"
        specific = Route.new "name", nil, path, constraints, defaults

        path = Path::Pattern.new "/:controller(/:action(/:id))(.:format)"
        generic = Route.new "name", nil, path, constraints

        knowledge = {:id=>20, :controller=>"pages", :action=>"show"}

        routes = [specific, generic]

        assert_not_equal specific.score(knowledge), generic.score(knowledge)

        found = routes.sort_by { |r| r.score(knowledge) }.last

        assert_equal specific, found
      end
    end
  end
end
