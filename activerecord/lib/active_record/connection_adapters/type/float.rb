module ActiveRecord
  module ConnectionAdapters
    module Type
      class Float < Value
        def type
          :float
        end
      end
    end
  end
end
