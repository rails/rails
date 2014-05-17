module ActiveRecord
  module ConnectionAdapters
    module Type
      class String < Value # :nodoc:
        def type
          :string
        end
      end
    end
  end
end
