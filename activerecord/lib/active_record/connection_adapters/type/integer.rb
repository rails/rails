module ActiveRecord
  module ConnectionAdapters
    module Type
      class Integer < Value
        def type
          :integer
        end
      end
    end
  end
end
