module ActionDispatch
  module Routing
    class Route #:nodoc:
      attr_reader :conditions, :path

      def initialize(set, app, conditions, requirements, defaults, name, anchor)
        @set = set
        path = ::Rack::Mount::Strexp.new(
          conditions[:path_info], requirements, SEPARATORS, anchor)

        @verbs = conditions[:request_method] || []

        @conditions = conditions.dup

        # Rack-Mount requires that :request_method be a regular expression.
        # :request_method represents the HTTP verb that matches this route.
        #
        # Here we munge values before they get sent on to rack-mount.
        @conditions[:request_method] = %r[^#{verb}$] unless @verbs.empty?
        @conditions[:path_info] = Rack::Mount::RegexpWithNamedGroups.new(path)
        @conditions.delete_if{ |k,v| k != :path_info && !valid_condition?(k) }
      end

      def verb
        @verbs.join '|'
      end

      def segment_keys
        @segment_keys ||= conditions[:path_info].names.compact.map { |key| key.to_sym }
      end

      private
        def valid_condition?(method)
          segment_keys.include?(method) || @set.valid_conditions.include?(method)
        end
    end
  end
end
