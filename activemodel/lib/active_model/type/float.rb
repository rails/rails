module ActiveModel
  module Type
    class Float < Value # :nodoc:
      include Helpers::Numeric

      def type
        :float
      end

      def type_cast_for_schema(value)
        return "::Float::NAN" if value.try(:nan?)
        case value
        when ::Float::INFINITY then "::Float::INFINITY"
        when -::Float::INFINITY then "-::Float::INFINITY"
        else super
        end
      end

      alias serialize cast

      private

        def cast_value(value)
          case value
          when ::Float then value
          when "Infinity" then ::Float::INFINITY
          when "-Infinity" then -::Float::INFINITY
          when "NaN" then ::Float::NAN
          else value.to_f
          end
        end
    end
  end
end
