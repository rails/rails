module ActionDispatch
  module Journey # :nodoc:
    # The Routing table. Contains all routes for a system. Routes can be
    # added to the table by calling Routes#add_route.
    class Routes # :nodoc:
      include Enumerable

      attr_reader :routes, :named_routes

      def initialize
        @routes             = []
        @named_routes       = {}
        @ast                = nil
        @partitioned_routes = nil
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
      end

      def partitioned_routes
        @partitioned_routes ||= routes.partition do |r|
          r.path.anchored && r.ast.grep(Nodes::Symbol).all?(&:default_regexp?)
        end
      end

      def ast
        @ast ||= begin
          asts = partitioned_routes.first.map(&:ast)
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
        clear_cache!
        route
      end

      private

        def clear_cache!
          @ast                = nil
          @partitioned_routes = nil
          @simulator          = nil
        end
    end
  end
end
