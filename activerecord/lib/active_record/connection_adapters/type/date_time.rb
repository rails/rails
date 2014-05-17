module ActiveRecord
  module ConnectionAdapters
    module Type
      class DateTime < Timestamp # :nodoc:
        def type
          :datetime
        end
      end
    end
  end
end
