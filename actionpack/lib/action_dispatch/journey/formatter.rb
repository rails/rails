require 'action_controller/metal/exceptions'
require 'active_support/deprecation'

module ActionDispatch
  module Journey
    # The Formatter class is used for formatting URLs. For example, parameters
    # passed to +url_for+ in Rails will eventually call Formatter#generate.
    class Formatter # :nodoc:
      attr_reader :routes

      def initialize(routes)
        @routes = routes
        @cache  = nil
      end

      def generate(name, options, path_parameters, parameterize = nil)
        constraints = path_parameters.merge(options)
        missing_keys = []

        match_route(name, constraints) do |route|
          parameterized_parts = extract_parameterized_parts(route, options, path_parameters, parameterize)

          # Skip this route unless a name has been provided or it is a
          # standard Rails route since we can't determine whether an options
          # hash passed to url_for matches a Rack application or a redirect.
          next unless name || route.dispatcher?

          missing_keys = missing_keys(route, parameterized_parts)
          next unless missing_keys.empty?
          params = options.dup.delete_if do |key, _|
            parameterized_parts.key?(key) || route.defaults.key?(key)
          end

          defaults       = route.defaults
          required_parts = route.required_parts
          parameterized_parts.delete_if do |key, value|
            value.to_s == defaults[key].to_s && !required_parts.include?(key)
          end

          return [route.format(parameterized_parts), params]
        end

        message = "No route matches #{Hash[constraints.sort].inspect}"
        message << " missing required keys: #{missing_keys.sort.inspect}" unless missing_keys.empty?

        raise ActionController::UrlGenerationError, message
      end

      def clear
        @cache = nil
      end

      private

        def extract_parameterized_parts(route, options, recall, parameterize = nil)
          parameterized_parts = recall.merge(options)

          keys_to_keep = route.parts.reverse.drop_while { |part|
            !options.key?(part) || (options[part] || recall[part]).nil?
          } | route.required_parts

          (parameterized_parts.keys - keys_to_keep).each do |bad_key|
            parameterized_parts.delete(bad_key)
          end

          if parameterize
            parameterized_parts.each do |k, v|
              parameterized_parts[k] = parameterize.call(k, v)
            end
          end

          parameterized_parts.keep_if { |_, v| v }
          parameterized_parts
        end

        def named_routes
          routes.named_routes
        end

        def match_route(name, options)
          if named_routes.key?(name)
            yield named_routes[name]
          else
            # Make sure we don't show the deprecation warning more than once
            warned = false

            routes = non_recursive(cache, options)

            hash = routes.group_by { |_, r| r.score(options) }

            hash.keys.sort.reverse_each do |score|
              break if score < 0

              hash[score].sort_by { |i, _| i }.each do |_, route|
                if name && !warned
                  ActiveSupport::Deprecation.warn <<-MSG.squish
                    You are trying to generate the URL for a named route called
                    #{name.inspect} but no such route was found. In the future,
                    this will result in an `ActionController::UrlGenerationError`
                    exception.
                  MSG

                  warned = true
                end

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

        # Returns an array populated with missing keys if any are present.
        def missing_keys(route, parts)
          missing_keys = []
          tests = route.path.requirements
          route.required_parts.each { |key|
            if tests.key?(key)
              missing_keys << key unless /\A#{tests[key]}\Z/ === parts[key]
            else
              missing_keys << key unless parts[key]
            end
          }
          missing_keys
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
          routes.each_with_index do |route, i|
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
end
