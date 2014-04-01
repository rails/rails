require 'abstract_unit'

module ActionDispatch
  module Routing
    class TestRoutes < ActiveSupport::TestCase
      def test_clear
        routes = Routes.new
        exp    = Router::Strexp.new '/foo(/:id)', {}, ['/.?']
        path   = Path.new exp
        requirements = { :hello => /world/ }

        routes.add_route nil, path, requirements, {:id => nil}, {}
        assert_equal 1, routes.length

        routes.clear
        assert_equal 0, routes.length
      end

      def test_first_name_wins
        #def add_route app, path, conditions, defaults, name = nil
        routes = Routes.new

        one   = Path.new '/hello'
        two   = Path.new '/aaron'

        routes.add_route nil, one, {}, {}, 'aaron'
        routes.add_route nil, two, {}, {}, 'aaron'

        assert_equal '/hello', routes.named_routes['aaron'].path.string
      end
    end
  end
end
