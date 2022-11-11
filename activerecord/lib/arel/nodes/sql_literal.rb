# frozen_string_literal: true

module Arel # :nodoc: all
  module Nodes
    class SqlLiteral < String
      include Arel::Expressions
      include Arel::Predications
      include Arel::AliasPredication
      include Arel::OrderPredications

      attr_reader :bypass_numeric_quoting

      def initialize(value, bypass_numeric_quoting: false)
        super(value.to_s)
        @bypass_numeric_quoting = bypass_numeric_quoting && is_number?(value)
      end

      def encode_with(coder)
        coder.scalar = self.to_s
      end

      def fetch_attribute
      end

      private
        INTEGER_REGEX = /\A[+-]?\d+\z/
        HEXADECIMAL_REGEX = /\A[+-]?0[xX]/
        private_constant :INTEGER_REGEX, :HEXADECIMAL_REGEX

        def is_number?(raw_value)
          !parse_as_number(raw_value).nil?
        rescue ArgumentError, TypeError
          false
        end

        def parse_as_number(raw_value)
          if raw_value.is_a?(Float)
            raw_value
          elsif raw_value.is_a?(BigDecimal)
            raw_value
          elsif raw_value.is_a?(Numeric)
            raw_value
          elsif is_integer?(raw_value)
            raw_value.to_i
          elsif !is_hexadecimal_literal?(raw_value)
            Kernel.Float(raw_value)
          end
        end

        def is_integer?(raw_value)
          INTEGER_REGEX.match?(raw_value)
        end

        def is_hexadecimal_literal?(raw_value)
          HEXADECIMAL_REGEX.match?(raw_value)
        end
    end
  end
end
