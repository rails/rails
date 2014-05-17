module ActiveRecord
  module ConnectionAdapters
    module Type
      class Boolean < Value
        def type
          :boolean
        end
      end
    end
  end
end
