# frozen_string_literal: true

require "bigdecimal/util"

module ActiveModel
  module Type
    # Attribute type for decimal, high-precision floating point numeric
    # representation. It is registered under the +:decimal+ key.
    #
    #   class BagOfCoffee
    #     include ActiveModel::Attributes
    #
    #     attribute :weight, :decimal
    #   end
    #
    #   bag = BagOfCoffee.new
    #   bag.weight = "0.0001"
    #
    #   bag.weight # => 0.1e-3
    #
    # Numeric instances are converted to BigDecimal instances. Any other objects
    # are cast using their +to_d+ method, if it exists. If it does not exist,
    # the object is converted to a string using +to_s+, which is then coerced to
    # a BigDecimal using +to_d+.
    #
    # Decimal precision defaults to 18, and can be customized when declaring an
    # attribute:
    #
    #   class BagOfCoffee
    #     include ActiveModel::Attributes
    #
    #     attribute :weight, :decimal, precision: 24
    #   end
    class Decimal < Value
      include Helpers::Numeric
      BIGDECIMAL_PRECISION = 18

      def type
        :decimal
      end

      def type_cast_for_schema(value)
        value.to_s.inspect
      end

      private
        def cast_value(value)
          casted_value = \
            case value
            when ::Float
              convert_float_to_big_decimal(value)
            when ::Numeric
              BigDecimal(value, precision || BIGDECIMAL_PRECISION)
            when ::String
              begin
                value.to_d
              rescue ArgumentError
                BigDecimal(0)
              end
            else
              if value.respond_to?(:to_d)
                value.to_d
              else
                cast_value(value.to_s)
              end
            end

          apply_scale(casted_value)
        end

        def convert_float_to_big_decimal(value)
          if precision
            BigDecimal(apply_scale(value), float_precision)
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

        def apply_scale(value)
          if scale
            value.round(scale)
          else
            value
          end
        end
    end
  end
end
