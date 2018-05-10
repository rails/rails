# frozen_string_literal: true

module ActionView #:nodoc:
  # = Action View HTML Template
  class Template #:nodoc:
    class HTML #:nodoc:
      attr_accessor :type

      def initialize(string, type = nil)
        @string = string.to_s
        @type   = Types[type] || type if type
        @type ||= Types[:html]
      end

      def identifier
        "html template"
      end

      alias_method :inspect, :identifier

      def to_str
        ERB::Util.h(@string)
      end

      def render(*_args)
        to_str
      end

      def formats
        [@type.respond_to?(:ref) ? @type.ref : @type.to_s]
      end
    end
  end
end
