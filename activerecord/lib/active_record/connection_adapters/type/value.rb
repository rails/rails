module ActiveRecord
  module ConnectionAdapters
    module Type
      class Value # :nodoc:
        def type; end

        def type_cast(value)
          cast_value(value) unless value.nil?
        end

        private

        def cast_value(value)
          value
        end
      end
    end
  end
end
