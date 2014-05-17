module ActiveRecord
  module ConnectionAdapters
    module Type
      class Integer < Value # :nodoc:
        def type
          :integer
        end
      end
    end
  end
end
