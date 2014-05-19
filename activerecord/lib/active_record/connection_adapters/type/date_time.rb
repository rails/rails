module ActiveRecord
  module ConnectionAdapters
    module Type
      class DateTime < Value # :nodoc:
        def type
          :datetime
        end
      end
    end
  end
end
