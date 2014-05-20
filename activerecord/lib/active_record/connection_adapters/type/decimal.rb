module ActiveRecord
  module ConnectionAdapters
    module Type
      class Decimal < Value # :nodoc:
        include Numeric

        def type
          :decimal
        end

        private

        def cast_value(value)
          Column.value_to_decimal(value)
        end
      end
    end
  end
end
