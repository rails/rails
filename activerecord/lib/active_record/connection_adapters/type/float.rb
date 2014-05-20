module ActiveRecord
  module ConnectionAdapters
    module Type
      class Float < Value # :nodoc:
        def type
          :float
        end

        private

        def cast_value(value)
          value.to_f
        end
      end
    end
  end
end
