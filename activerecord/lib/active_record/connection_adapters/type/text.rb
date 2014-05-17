module ActiveRecord
  module ConnectionAdapters
    module Type
      class Text < String # :nodoc:
        def type
          :text
        end
      end
    end
  end
end
