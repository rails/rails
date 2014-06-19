module ActionDispatch
  module Journey # :nodoc:
    # The Routing table. Contains all routes for a system. Routes can be
    # added to the table by calling Routes#add_route.
    class Routes # :nodoc:
      include Enumerable

      attr_reader :routes, :named_routes, :custom_routes, :anchored_routes

      def initialize
        @routes             = []
        @named_routes       = {}
        @ast                = nil
        @anchored_routes    = []
        @custom_routes      = []
        @simulator          = nil
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
        routes.clear
        anchored_routes.clear
        custom_routes.clear
        named_routes.clear
      end

      def partition_route(route)
        if route.path.anchored && route.ast.grep(Nodes::Symbol).all?(&:default_regexp?)
          anchored_routes << route
        else
          custom_routes << route
        end
      end

      def ast
        @ast ||= begin
          asts = anchored_routes.map(&:ast)
          Nodes::Or.new(asts) unless asts.empty?
        end
      end

      def simulator
        @simulator ||= begin
          gtg = GTG::Builder.new(ast).transition_table
          GTG::Simulator.new(gtg)
        end
      end

      # Add a route to the routing table.
      def add_route(app, path, conditions, defaults, name = nil)
        route = Route.new(name, app, path, conditions, defaults)

        route.precedence = routes.length
        routes << route
        named_routes[name] = route if name && !named_routes[name]
        partition_route(route)
        clear_cache!
        route
      end

      private

        def clear_cache!
          @ast                = nil
          @simulator          = nil
        end
    end
  end
end
