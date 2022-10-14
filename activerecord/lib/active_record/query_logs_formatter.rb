# frozen_string_literal: true

module ActiveRecord
  module QueryLogs
    class LegacyFormatter # :nodoc:
      def initialize
        @key_value_separator = ":"
      end

      # Formats the key value pairs into a string.
      def format(key, value)
        "#{key}#{key_value_separator}#{format_value(value)}"
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

      private
        def format_value(value)
          "'#{value.to_s.gsub("'", "\\\\'")}'"
        end
    end
  end
end
