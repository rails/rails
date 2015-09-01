module ActiveRecord
  module Type
    class Decimal < Value # :nodoc:
      include Numeric

      def type
        :decimal
      end

      def type_cast_for_schema(value)
        value.to_s
      end

      private

      def cast_value(value)
        casted_value = case value
        when ::Float
          convert_float_to_big_decimal(value)
        when ::Numeric, ::String
          BigDecimal(value, precision.to_i)
        else
          if value.respond_to?(:to_d)
            value.to_d
          else
            cast_value(value.to_s)
          end
        end

        scale ? casted_value.round(scale) : casted_value
      end

      def convert_float_to_big_decimal(value)
        if precision
          BigDecimal(value, float_precision)
        else
          value.to_d
        end
      end

      def float_precision
        if precision.to_i > ::Float::DIG + 1
          ::Float::DIG + 1
        else
          precision.to_i
        end
      end
    end
  end
end
