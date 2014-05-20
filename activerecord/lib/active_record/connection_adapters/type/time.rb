module ActiveRecord
  module ConnectionAdapters
    module Type
      class Time < Value # :nodoc:
        include TimeValue

        def type
          :time
        end

        private

        def cast_value(value)
          Column.string_to_dummy_time(value)
        end
      end
    end
  end
end
