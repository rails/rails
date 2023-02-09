# frozen_string_literal: true

module ActiveRecord
  module QueryLogs
    class LegacyFormatter # :nodoc:
      def initialize
        @key_value_separator = ":"
      end

      # Formats the key value pairs into a string.
      def format(pairs)
        pairs.map! do |key, value|
          "#{key}#{key_value_separator}#{format_value(value)}"
        end.join(",")
      end

      private
        attr_reader :key_value_separator

        def format_value(value)
          value
        end
    end

    class SQLCommenter < LegacyFormatter # :nodoc:
      def initialize
        @key_value_separator = "="
      end

      def format(pairs)
        pairs.sort_by!(&:first)
        super
      end

      private
        def format_value(value)
          "'#{ERB::Util.url_encode(value)}'"
        end
    end
  end
end
