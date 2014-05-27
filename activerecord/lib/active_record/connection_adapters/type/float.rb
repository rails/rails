module ActiveRecord
  module ConnectionAdapters
    module Type
      class Float < Value # :nodoc:
        include Numeric

        def type
          :float
        end

        def klass
          ::Float
        end

        alias type_cast_for_database type_cast

        private

        def cast_value(value)
          value.to_f
        end
      end
    end
  end
end
