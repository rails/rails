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
        @static_exact_map   = nil
      end

      def freeze
        ast
        simulator
        static_exact_map

        super
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
        clear_cache!
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

      # Maps a request method and an exact path to the route that is certain
      # to be the first match for it, e.g. "GET /posts" for a "/posts(.:format)"
      # route, so that request-time matching for static paths is a Hash lookup
      # that captures no parameters, instead of a simulator walk, a Regexp
      # match, and parameter extraction.
      #
      # Only routes that leave no room for request-dependent behavior are
      # included: anchored, a single concrete request method, no extra request
      # constraints, and a path that is all literals once trailing optional
      # groups are dropped. Paths that an earlier route (static or dynamic)
      # could also match are excluded at build time, preserving precedence.
      def static_exact_map
        @static_exact_map ||= begin
          map = {}

          anchored_routes.each do |route|
            next unless route.constraints.empty?
            next unless (verb = single_verb_for(route))
            next unless (path = static_exact_path(route))

            bucket = (map[verb] ||= {})
            bucket[path] = route unless bucket.key?(path) || shadowed?(route, path)
          end

          map.each_value(&:freeze)
          map.freeze
        end
      end

      def visualizer
        tt     = GTG::Builder.new(ast).transition_table
        groups = anchored_routes.map(&:ast).group_by(&:to_s)
        asts   = groups.values.map(&:first)
        tt.visualizer(asts)
      end

      private
        def clear_cache!
          @ast                = nil
          @simulator          = nil
          @static_exact_map   = nil
        end

        def single_verb_for(route)
          verb = route.verb
          verb unless verb.empty? || verb.include?("|")
        end

        # The exact path a request must carry to match the route statically:
        # its literal spec with trailing optional groups dropped. nil when the
        # route has dynamic segments outside optional groups.
        def static_exact_path(route)
          atoms = flatten_cat(route.path.spec, [])

          path = +""
          seen_group = false
          atoms.each do |atom|
            case atom.type
            when :LITERAL, :SLASH, :DOT
              return nil if seen_group
              path << atom.left
            when :GROUP
              seen_group = true
            else
              return nil
            end
          end
          return nil if path.empty?

          # The pattern itself has the final say: it must match the path
          # without capturing anything.
          match_data = route.path.match(path)
          return nil unless match_data && match_data.captures.all?(&:nil?)

          -path
        end

        def flatten_cat(node, atoms)
          if node.type == :CAT
            flatten_cat(node.left, atoms)
            flatten_cat(node.right, atoms)
          else
            atoms << node
          end
          atoms
        end

        # Would a route defined earlier also match this path? The candidates come
        # from the simulator, as at request time, which keeps building the map
        # linear in the number of routes. Verb overlap is judged conservatively:
        # only provably disjoint request methods rule a route out.
        def shadowed?(route, path)
          candidates = simulator.memos(path) { [] } + custom_routes.select { |r| r.path.match?(path) }

          candidates.any? do |earlier|
            earlier.precedence < route.precedence && verbs_may_overlap?(earlier, route)
          end
        end

        def verbs_may_overlap?(a, b)
          a_verb, b_verb = a.verb, b.verb
          a_verb.empty? || b_verb.empty? || a_verb.include?(b_verb) || b_verb.include?(a_verb)
        end
    end
  end
end
