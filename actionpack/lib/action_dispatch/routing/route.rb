module ActionDispatch
  module Routing
    class Route #:nodoc:
      attr_reader :app, :conditions, :defaults, :name
      attr_reader :path, :requirements

      def initialize(app, conditions, requirements, defaults, name, anchor)
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
          conditions[:path_info] = ::Rack::Mount::Strexp.compile(path, requirements, SEPARATORS, anchor)
        end

        @conditions = conditions.inject({}) { |h, (k, v)|
          h[k] = Rack::Mount::RegexpWithNamedGroups.new(v)
          h
        }
      end

      def verb
        if method = conditions[:request_method]
          case method
          when Regexp
            method.source.upcase
          else
            method.to_s.upcase
          end
        end
      end

      def segment_keys
        @segment_keys ||= conditions[:path_info].names.compact.map { |key| key.to_sym }
      end

      def to_a
        [@app, @conditions, @defaults, @name]
      end

      def to_s
        @to_s ||= begin
          "%-6s %-40s %s" % [(verb || :any).to_s.upcase, path, requirements.inspect]
        end
      end
    end
  end
end
