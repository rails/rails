module ActiveRecord
  module ConnectionAdapters
    module Type
      class Decimal < Value
        def type
          :decimal
        end
      end
    end
  end
end
