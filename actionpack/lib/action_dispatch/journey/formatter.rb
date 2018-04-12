# frozen_string_literal: true

require "action_controller/metal/exceptions"

module ActionDispatch
  # :stopdoc:
  module Journey
    # The Formatter class is used for formatting URLs. For example, parameters
    # passed to +url_for+ in Rails will eventually call Formatter#generate.
    class Formatter
      attr_reader :routes

      def initialize(routes)
        @routes = routes
        @cache  = nil
      end

      def generate(name, options, path_parameters, parameterize = nil)
        constraints = path_parameters.merge(options)
        matched_route = nil

        match_route(name, constraints) do |route|
          matched_route = MatchedRoute.new(route, constraints, options, path_parameters, parameterize)

          next if matched_route.invalid?

          return matched_route.generate
        end

        messages = ["No route matches #{constraints.sort_by { |k, _| k.to_s }.to_h.inspect}"]
        if matched_route
          unless matched_route.sanitized_missing_keys.empty?
            messages << "missing required keys: #{matched_route.sanitized_missing_keys.inspect}"
          end

          unless matched_route.unmatched_keys.empty?
            messages << "possible unmatched constraints: #{matched_route.unmatched_keys.inspect}"
          end
        end

        raise ActionController::UrlGenerationError, messages.join(", ")
      end

      def clear
        @cache = nil
      end

      private


        def named_routes
          routes.named_routes
        end

        def match_route(name, options)
          if named_routes.key?(name)
            yield named_routes[name]
          else
            routes = non_recursive(cache, options)

            supplied_keys = options.each_with_object({}) do |(k, v), h|
              h[k.to_s] = true if v
            end

            hash = routes.group_by { |_, r| r.score(supplied_keys) }

            hash.keys.sort.reverse_each do |score|
              break if score < 0

              hash[score].sort_by { |i, _| i }.each do |_, route|
                # Skip this route unless a name has been provided or it is a
                # standard Rails route since we can't determine whether an options
                # hash passed to url_for matches a Rack application or a redirect.
                next unless name || route.dispatcher?

                yield route
              end
            end
          end
        end

        def non_recursive(cache, options)
          routes = []
          queue  = [cache]

          while queue.any?
            c = queue.shift
            routes.concat(c[:___routes]) if c.key?(:___routes)

            options.each do |pair|
              queue << c[pair] if c.key?(pair)
            end
          end

          routes
        end

        def possibles(cache, options, depth = 0)
          cache.fetch(:___routes) { [] } + options.find_all { |pair|
            cache.key?(pair)
          }.flat_map { |pair|
            possibles(cache[pair], options, depth + 1)
          }
        end

        def build_cache
          root = { ___routes: [] }
          routes.routes.each_with_index do |route, i|
            leaf = route.required_defaults.inject(root) do |h, tuple|
              h[tuple] ||= {}
            end
            (leaf[:___routes] ||= []) << [i, route]
          end
          root
        end

        def cache
          @cache ||= build_cache
        end
    end
  end
  # :startdoc:
end
