# frozen_string_literal: true

module ActiveRecord
  module QueryLogs
    class Formatter # :nodoc:
      attr_reader :key_value_separator

      # @param [String] key_value_separator: indicates the string used for
      # separating keys and values.
      #
      # @param [Symbol] quote_values: indicates how values will be formatted (eg:
      # in single quotes, not quoted at all, etc)
      def initialize(key_value_separator:)
        @key_value_separator = key_value_separator
      end

      # @param [String-coercible] value
      # @return [String] The formatted value that will be used in our key-value
      # pairs.
      def format_value(value)
        value
      end
    end

    class QuotingFormatter < Formatter # :nodoc:
      def format_value(value)
        "'#{value.to_s.gsub("'", "\\\\'")}'"
      end
    end
  end
end
