module ActiveRecord
  module ConnectionAdapters
    module Type
      class Time < Value
        def type
          :time
        end
      end
    end
  end
end
