# frozen_string_literal: true

module ActiveRecord
  module QueryLogs
    class Formatter # :nodoc:
      attr_reader :key_value_separator

      def initialize(key_value_separator:)
        @key_value_separator = key_value_separator
      end

      def format_value(value)
        value
      end
    end

    class QuotingFormatter < Formatter # :nodoc:
      def format_value(value)
        "'#{value.to_s.gsub("'", "\\\\'")}'"
      end
    end

    class FormatterFactory # :nodoc:
      def self.from_symbol(formatter)
        case formatter
        when :marginalia
          Formatter.new(key_value_separator: ":")
        when :sqlcommenter
          QuotingFormatter.new(key_value_separator: "=")
        else
          raise ArgumentError, "Formatter is unsupported: #{formatter}"
        end
      end
    end
  end
end
