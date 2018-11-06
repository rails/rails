# frozen_string_literal: true

module ActiveRecord
  module Type
    class DecimalWithoutScale < ActiveModel::Type::BigInteger # :nodoc:
      def type
        :decimal
      end

      def type_cast_for_schema(value)
        value.to_s.inspect
      end

      def serialize(value)
        raise ActiveModel::RangeError, "cannot be infinite" if is_infinite?(value)
        super
      end

      private

        def cast_value(value)
          if is_infinite?(value)
            value
          else
            super
          end
        end

        def is_infinite?(value)
          value&.to_d&.infinite?
        end
    end
  end
end
