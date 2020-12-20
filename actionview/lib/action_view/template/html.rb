# frozen_string_literal: true

module ActionView #:nodoc:
  # = Action View HTML Template
  class Template #:nodoc:
    class HTML #:nodoc:
      attr_reader :type

      def initialize(string, type)
        @string = string.to_s
        @type   = type
      end

      def identifier
        "html template"
      end

      alias_method :inspect, :identifier

      def to_str
        ERB::Util.h(@string)
      end

      def render(*args)
        to_str
      end

      def format
        @type
      end
    end
  end
end
