module ActiveRecord
  module ConnectionAdapters
    module Type
      class Date < Value # :nodoc:
        def type
          :date
        end

        private

        def cast_value(value)
          Column.value_to_date(value)
        end
      end
    end
  end
end
