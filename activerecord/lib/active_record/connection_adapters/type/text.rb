module ActiveRecord
  module ConnectionAdapters
    module Type
      class Text < String
        def type
          :text
        end
      end
    end
  end
end
