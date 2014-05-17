module ActiveRecord
  module ConnectionAdapters
    module Type
      class Decimal < Value # :nodoc:
        def type
          :decimal
        end
      end
    end
  end
end
