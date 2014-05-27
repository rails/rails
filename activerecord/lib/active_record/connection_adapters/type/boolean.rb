module ActiveRecord
  module ConnectionAdapters
    module Type
      class Boolean < Value # :nodoc:
        def type
          :boolean
        end

        private

        def cast_value(value)
          if value == ''
            nil
          else
            Column::TRUE_VALUES.include?(value)
          end
        end
      end
    end
  end
end
