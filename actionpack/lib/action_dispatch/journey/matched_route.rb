# frozen_string_literal: true

module ActionDispatch
  module Journey # :nodoc:
    class MatchedRoute # :nodoc:
      delegate :defaults, :required_parts, :grouped_optional_parts, to: :@route

      def initialize(route, constraints, options, path_parameters, parameterize)
        @route = route
        @constraints = constraints
        @options = options
        @path_parameters = path_parameters
        @parameterize = parameterize
      end

      def parameterized_parts
        @parameterized_parts ||= @constraints.dup.tap do |parameterized_parts|
          keys_to_keep = @route.parts.reverse_each.drop_while { |part|
            !@options.key?(part) || (@options[part] || @path_parameters[part]).nil?
          } | required_parts

          parameterized_parts.delete_if do |bad_key, _|
            !keys_to_keep.include?(bad_key)
          end

          if @parameterize
            parameterized_parts.each do |k, v|
              parameterized_parts[k] = @parameterize.call(k, v)
            end
          end

          parameterized_parts.keep_if { |_, v| v }
        end
      end

      def tests
        @tests ||= @route.path.requirements
      end

      module RegexCaseComparator
        DEFAULT_INPUT = /[-_.a-zA-Z0-9]+\/[-_.a-zA-Z0-9]+/
        DEFAULT_REGEX = /\A#{DEFAULT_INPUT}\Z/

        def self.===(regex)
          DEFAULT_INPUT == regex
        end
      end

      def missing_keys
        @missing_keys ||= required_parts.each_with_object([]) do |key, memo|
          case tests[key]
          when nil
            unless parameterized_parts[key]
              memo << key
            end
          when RegexCaseComparator
            unless RegexCaseComparator::DEFAULT_REGEX === parameterized_parts[key]
              memo << key
            end
          else
            unless /\A#{tests[key]}\Z/ === parameterized_parts[key]
              memo << key
            end
          end
        end
      end

      def invalid?
        !missing_keys.empty?
      end

      def params
        @options.reject do |key, _|
          parameterized_parts.key?(key) || defaults.key?(key)
        end
      end

      def formatted_route
        parts = parameterized_parts.dup

        grouped_optional_parts.each do |group|
          group.reverse_each do |key|
            break if defaults[key].nil? && parts[key].present?
            break if parts[key].to_s != defaults[key].to_s
            break if required_parts.include?(key)

            parts.delete(key)
          end
        end

        @route.format(parts)
      end

      def generate
        [formatted_route, params]
      end

      def unmatched_keys
        @unmatched_keys ||= (missing_keys & @constraints.keys).sort
      end

      def sanitized_missing_keys
        @sanitized_missing_keys ||= (missing_keys - unmatched_keys).sort
      end
    end
  end
end
