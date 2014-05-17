module ActiveRecord
  module ConnectionAdapters
    module Type
      class Date < Value
        def type
          :date
        end
      end
    end
  end
end
