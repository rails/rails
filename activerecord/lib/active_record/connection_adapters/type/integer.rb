module ActiveRecord
  module ConnectionAdapters
    module Type
      class Integer < Value # :nodoc:
        def type
          :integer
        end

        private

        def cast_value(value)
          Column.value_to_integer(value)
        end
      end
    end
  end
end
