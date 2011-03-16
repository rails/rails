require 'active_support/core_ext/module/deprecation'

module ActionDispatch
  module Routing
    class Route #:nodoc:
      attr_reader :app, :conditions, :defaults, :name
      attr_reader :path, :requirements, :set

      def initialize(set, app, conditions, requirements, defaults, name, anchor)
        @set = set
        @app = app
        @defaults = defaults
        @name = name

        # FIXME: we should not be doing this much work in a constructor.

        @requirements = requirements.merge(defaults)
        @requirements.delete(:controller) if @requirements[:controller].is_a?(Regexp)
        @requirements.delete_if { |k, v|
          v == Regexp.compile("[^#{SEPARATORS.join}]+")
        }

        if path = conditions[:path_info]
          @path = path
          conditions[:path_info] = ::Rack::Mount::Strexp.compile(path, requirements, SEPARATORS, anchor)
        end

        @verbs = conditions[:request_method] || []

        @conditions = conditions.dup

        # Rack-Mount requires that :request_method be a regular expression.
        # :request_method represents the HTTP verb that matches this route.
        #
        # Here we munge values before they get sent on to rack-mount.
        @conditions[:request_method] = %r[^#{verb}$] unless @verbs.empty?
        @conditions[:path_info] = Rack::Mount::RegexpWithNamedGroups.new(@conditions[:path_info]) if @conditions[:path_info]
        @conditions.delete_if{ |k,v| k != :path_info && !valid_condition?(k) }
        @requirements.delete_if{ |k,v| !valid_condition?(k) }
      end

      def verb
        @verbs.join '|'
      end

      def segment_keys
        @segment_keys ||= conditions[:path_info].names.compact.map { |key| key.to_sym }
      end

      def to_a
        [@app, @conditions, @defaults, @name]
      end
      deprecate :to_a

      def to_s
        @to_s ||= begin
          "%-6s %-40s %s" % [(verb || :any).to_s.upcase, path, requirements.inspect]
        end
      end

      private
        def valid_condition?(method)
          segment_keys.include?(method) || set.valid_conditions.include?(method)
        end
    end
  end
end
