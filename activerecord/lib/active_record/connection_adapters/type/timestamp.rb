module ActiveRecord
  module ConnectionAdapters
    module Type
      class Timestamp < Value
        def type
          :timestamp
        end
      end
    end
  end
end
