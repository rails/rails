# frozen_string_literal: true

module ActionView # :nodoc:
  # = Action View Text Template
  class Template # :nodoc:
    class Text # :nodoc:
      attr_accessor :type

      def initialize(string)
        @string = string.to_s
      end

      def identifier
        "text template"
      end

      alias_method :inspect, :identifier

      def to_str
        @string
      end

      def render(*args)
        to_str
      end

      def format
        :text
      end
    end
  end
end
