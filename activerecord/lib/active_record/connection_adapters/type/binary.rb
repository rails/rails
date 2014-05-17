module ActiveRecord
  module ConnectionAdapters
    module Type
      class Binary < Value
        def type
          :binary
        end
      end
    end
  end
end
