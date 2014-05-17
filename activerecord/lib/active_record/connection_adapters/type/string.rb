module ActiveRecord
  module ConnectionAdapters
    module Type
      class String < Value
        def type
          :string
        end
      end
    end
  end
end
