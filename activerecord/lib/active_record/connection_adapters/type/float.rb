module ActiveRecord
  module ConnectionAdapters
    module Type
      class Float < Value # :nodoc:
        def type
          :float
        end
      end
    end
  end
end
