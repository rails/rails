require './lib/action_dispatch/routing/trie'

module ActionDispatch
  module Routing # :nodoc:
    # The Routing table. Contains all routes for a system. Routes can be
    # added to the table by calling Routes#add_route.
    class Routes # :nodoc:
      include Enumerable

      attr_reader :routes, :named_routes, :irregular_routes

      def initialize
        @trie               = nil
        @routes             = []
        @named_routes       = {}
        @partitioned_routes = nil
        @irregular_routes   = []
      end

      def length
        routes.length
      end
      alias :size :length

      def last
        routes.last
      end

      def each(&block)
        routes.each(&block)
      end

      def clear
        @trie = nil
        routes.clear
        named_routes.clear
      end

      def partitioned_routes
        default_regexp = /[^\.\/\?]+/

        @partitioned_routes ||= routes.partition do |r|
          r.path.anchored && r.requirements.all? { |_, v| v == default_regexp }
        end
      end

      # Add a route to the routing table.
      def add_route(app, path, conditions, defaults, name = nil)
        route = Route.new(name, app, path, conditions, defaults)

        route.precedence = routes.length

        if route.regular?
          trie.add(path.string, route)
        else
          irregular_routes << route
        end

        routes << route
        named_routes[name] = route if name && !named_routes[name]
        clear_cache!

        route
      end

      def match(path)
        trie.find(path)
      end

      private

        def trie
          @trie ||= Trie.new
        end

        def clear_cache!
          @partitioned_routes = nil
        end
    end
  end
end
