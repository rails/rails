module ActiveRecord
  module ConnectionAdapters
    module Type
      class Boolean < Value # :nodoc:
        def type
          :boolean
        end
      end
    end
  end
end
