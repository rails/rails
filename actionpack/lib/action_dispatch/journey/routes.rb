# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module Journey # :nodoc:
    # The Routing table. Contains all routes for a system. Routes can be added to
    # the table by calling Routes#add_route.
    class Routes # :nodoc:
      include Enumerable

      attr_reader :routes, :custom_routes, :anchored_routes

      def initialize(routes = [])
        @routes             = routes
        @ast                = nil
        @anchored_routes    = []
        @custom_routes      = []
        @simulator          = nil
      end

      def empty?
        routes.empty?
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
      end

      def partition_route(route)
        if route.path.anchored && route.path.requirements_anchored?
          anchored_routes << route
        else
          custom_routes << route
        end
      end

      def ast
        @ast ||= begin
          nodes = anchored_routes.map(&:ast)
          Nodes::Or.new(nodes)
        end
      end

      def simulator
        @simulator ||= begin
          gtg = GTG::Builder.new(ast).transition_table
          GTG::Simulator.new(gtg)
        end
      end

      def add_route(name, mapping)
        route = mapping.make_route name, routes.length
        routes << route
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
