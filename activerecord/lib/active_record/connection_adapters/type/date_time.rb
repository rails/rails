module ActiveRecord
  module ConnectionAdapters
    module Type
      class DateTime < Timestamp
        def type
          :datetime
        end
      end
    end
  end
end
