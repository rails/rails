module ActiveRecord
  module ConnectionAdapters
    module Type
      class Integer < Value
        include Numeric

        def type
          :integer
        end

        def klass
          ::Fixnum
        end

        alias type_cast_for_database type_cast

        private

        def cast_value(value)
          case value
          when true then 1
          when false then 0
          else value.to_i rescue nil
          end
        end
      end
    end
  end
end
