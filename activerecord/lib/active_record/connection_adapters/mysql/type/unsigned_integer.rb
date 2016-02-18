module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module Type
        class UnsignedInteger < ActiveRecord::Type::Integer # :nodoc:
          private

          def max_value
            super * 2
          end

          def min_value
            0
          end
        end
      end
    end
  end
end
