module ActiveRecord
  module ConnectionAdapters
    module Type
      class Value # :nodoc:
        def type; end

        def type_cast(value)
          cast_value(value) unless value.nil?
        end

        def type_cast_for_write(value)
          value
        end

        def text?
          false
        end

        def number?
          false
        end

        def binary?
          false
        end

        private

        def cast_value(value)
          value
        end
      end
    end
  end
end
