module ActionDispatch
  module Routing
    class Route #:nodoc:
      attr_reader :conditions, :path

      def initialize(valid_conditions, app, conditions, requirements, defaults, name, anchor)
        @valid_conditions = valid_conditions
        strexp = Journey::Router::Strexp.new(
            conditions.delete(:path_info),
            requirements,
            SEPARATORS,
            anchor)

        @path = Journey::Path::Pattern.new(strexp)

        @verbs = conditions[:request_method] || []

        @conditions = conditions.dup

        # Rack-Mount requires that :request_method be a regular expression.
        # :request_method represents the HTTP verb that matches this route.
        #
        # Here we munge values before they get sent on to rack-mount.
        unless @verbs.empty?
          @conditions[:request_method] = %r[^#{@verbs.join('|')}$]
        end
        @conditions.delete_if{ |k,v| !valid_condition?(k) }
      end

      def segment_keys
        @segment_keys ||= path.names.compact.map { |key| key.to_sym }
      end

      private
        def valid_condition?(method)
          segment_keys.include?(method) || @valid_conditions.include?(method)
        end
    end
  end
end
