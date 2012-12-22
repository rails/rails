require 'abstract_unit'

module ActionDispatch
  module Journey
    class TestRoutes < MiniTest::Unit::TestCase
      def test_clear
        routes = Routes.new
        exp    = Router::Strexp.new '/foo(/:id)', {}, ['/.?']
        path   = Path::Pattern.new exp
        requirements = { :hello => /world/ }

        routes.add_route nil, path, requirements, {:id => nil}, {}
        assert_equal 1, routes.length

        routes.clear
        assert_equal 0, routes.length
      end

      def test_ast
        routes = Routes.new
        path   = Path::Pattern.new '/hello'

        routes.add_route nil, path, {}, {}, {}
        ast = routes.ast
        routes.add_route nil, path, {}, {}, {}
        refute_equal ast, routes.ast
      end

      def test_simulator_changes
        routes = Routes.new
        path   = Path::Pattern.new '/hello'

        routes.add_route nil, path, {}, {}, {}
        sim = routes.simulator
        routes.add_route nil, path, {}, {}, {}
        refute_equal sim, routes.simulator
      end

      def test_first_name_wins
        #def add_route app, path, conditions, defaults, name = nil
        routes = Routes.new

        one   = Path::Pattern.new '/hello'
        two   = Path::Pattern.new '/aaron'

        routes.add_route nil, one, {}, {}, 'aaron'
        routes.add_route nil, two, {}, {}, 'aaron'

        assert_equal '/hello', routes.named_routes['aaron'].path.spec.to_s
      end
    end
  end
end
