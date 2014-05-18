module ActiveRecord
  module ConnectionAdapters
    module Type
      class Value # :nodoc:
        def type; end

        def type_cast(value)
          return nil if value.nil?
          cast_value(value)
        end

        private

        def cast_value(value)
          value
        end
      end
    end
  end
end
