module ActiveRecord
  module ConnectionAdapters
    module Type
      class Timestamp < Value # :nodoc:
        def type
          :timestamp
        end
      end
    end
  end
end
