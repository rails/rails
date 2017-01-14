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
        missing_keys = nil # need for variable scope

        match_route(name, constraints) do |route|
          parameterized_parts = extract_parameterized_parts(route, options, path_parameters, parameterize)

          # Skip this route unless a name has been provided or it is a
          # standard Rails route since we can't determine whether an options
          # hash passed to url_for matches a Rack application or a redirect.
          next unless name || route.dispatcher?

          missing_keys = missing_keys(route, parameterized_parts)
          next if missing_keys && !missing_keys.empty?
          params = options.dup.delete_if do |key, _|
            parameterized_parts.key?(key) || route.defaults.key?(key)
          end

          defaults       = route.defaults
          required_parts = route.required_parts

          route.parts.reverse_each do |key|
            break if defaults[key].nil? && parameterized_parts[key].present?
            next if parameterized_parts[key].to_s != defaults[key].to_s
            break if required_parts.include?(key)

            parameterized_parts.delete(key)
          end

          return [route.format(parameterized_parts), params]
        end

        unmatched_keys = (missing_keys || []) & constraints.keys
        missing_keys = (missing_keys || []) - unmatched_keys

        message = "No route matches #{Hash[constraints.sort_by { |k, v| k.to_s }].inspect}"
        message << ", missing required keys: #{missing_keys.sort.inspect}" if missing_keys && !missing_keys.empty?
        message << ", possible unmatched constraints: #{unmatched_keys.sort.inspect}" if unmatched_keys && !unmatched_keys.empty?

        raise ActionController::UrlGenerationError, message
      end

      def clear
        @cache = nil
      end

      private

        def extract_parameterized_parts(route, options, recall, parameterize = nil)
          parameterized_parts = recall.merge(options)

          keys_to_keep = route.parts.reverse_each.drop_while { |part|
            !options.key?(part) || (options[part] || recall[part]).nil?
          } | route.required_parts

          parameterized_parts.delete_if do |bad_key, _|
            !keys_to_keep.include?(bad_key)
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
            routes = non_recursive(cache, options)

            supplied_keys = options.each_with_object({}) do |(k, v), h|
              h[k.to_s] = true if v
            end

            hash = routes.group_by { |_, r| r.score(supplied_keys) }

            hash.keys.sort.reverse_each do |score|
              break if score < 0

              hash[score].sort_by { |i, _| i }.each do |_, route|
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

        module RegexCaseComparator
          DEFAULT_INPUT = /[-_.a-zA-Z0-9]+\/[-_.a-zA-Z0-9]+/
          DEFAULT_REGEX = /\A#{DEFAULT_INPUT}\Z/

          def self.===(regex)
            DEFAULT_INPUT == regex
          end
        end

        # Returns an array populated with missing keys if any are present.
        def missing_keys(route, parts)
          missing_keys = nil
          tests = route.path.requirements
          route.required_parts.each { |key|
            case tests[key]
            when nil
              unless parts[key]
                missing_keys ||= []
                missing_keys << key
              end
            when RegexCaseComparator
              unless RegexCaseComparator::DEFAULT_REGEX === parts[key]
                missing_keys ||= []
                missing_keys << key
              end
            else
              unless /\A#{tests[key]}\Z/ === parts[key]
                missing_keys ||= []
                missing_keys << key
              end
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
