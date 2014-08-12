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
        case value
        when ::Float
          BigDecimal(value, float_precision)
        when ::Numeric, ::String
          BigDecimal(value, precision.to_i)
        else
          if value.respond_to?(:to_d)
            value.to_d
          else
            cast_value(value.to_s)
          end
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
