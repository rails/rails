module ActiveRecord
  module ConnectionAdapters
    module Type
      class DateTime < Value # :nodoc:
        def type
          :datetime
        end

        private

        def cast_value(string)
          Column.string_to_time(string)
        end
      end
    end
  end
end
