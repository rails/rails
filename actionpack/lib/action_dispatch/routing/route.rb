module ActionDispatch
  module Routing
    class Route #:nodoc:
      attr_reader :app, :conditions, :defaults, :name
      attr_reader :path, :requirements

      def initialize(app, conditions = {}, requirements = {}, defaults = {}, name = nil)
        @app = app
        @defaults = defaults
        @name = name

        @requirements = requirements.merge(defaults)
        @requirements.delete(:controller) if @requirements[:controller].is_a?(Regexp)
        @requirements.delete_if { |k, v|
          v == Regexp.compile("[^#{SEPARATORS.join}]+")
        }

        if path = conditions[:path_info]
          @path = path
          conditions[:path_info] = ::Rack::Mount::Strexp.compile(path, requirements, SEPARATORS)
        end

        @conditions = conditions.inject({}) { |h, (k, v)|
          h[k] = Rack::Mount::RegexpWithNamedGroups.new(v)
          h
        }
      end

      def verb
        if verb = conditions[:verb]
          verb.to_s.upcase
        end
      end

      def segment_keys
        @segment_keys ||= conditions[:path_info].names.compact.map { |key| key.to_sym }
      end

      def to_ary
        [@app, @conditions, @defaults, @name]
      end
    end
  end
end
