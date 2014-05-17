module ActiveRecord
  module ConnectionAdapters
    module Type
      class Date < Value # :nodoc:
        def type
          :date
        end
      end
    end
  end
end
