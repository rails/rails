module ActiveRecord
  module ConnectionAdapters
    module Type
      class Time < Value # :nodoc:
        def type
          :time
        end
      end
    end
  end
end
