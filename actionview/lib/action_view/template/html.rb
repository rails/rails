# frozen_string_literal: true

require "active_support/deprecation"

module ActionView #:nodoc:
  # = Action View HTML Template
  class Template #:nodoc:
    class HTML #:nodoc:
      attr_reader :type

      def initialize(string, type = nil)
        unless type
          ActiveSupport::Deprecation.warn "ActionView::Template::HTML#initialize requires a type parameter"
          type = :html
        end

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

      def formats; Array(format); end
      deprecate :formats
    end
  end
end
