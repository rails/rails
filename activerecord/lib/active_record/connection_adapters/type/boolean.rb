module ActiveRecord
  module ConnectionAdapters
    module Type
      class Boolean < Value # :nodoc:
        def type
          :boolean
        end

        private

        def cast_value(value)
          Column.value_to_boolean(value)
        end
      end
    end
  end
end
