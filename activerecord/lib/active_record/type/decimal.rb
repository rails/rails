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
        if value.is_a?(::Numeric) || value.is_a?(::String)
          BigDecimal(value, precision.to_i)
        elsif value.respond_to?(:to_d)
          value.to_d
        else
          cast_value(value.to_s)
        end
      end
    end
  end
end
