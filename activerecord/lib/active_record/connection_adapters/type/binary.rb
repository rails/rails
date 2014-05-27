module ActiveRecord
  module ConnectionAdapters
    module Type
      class Binary < Value # :nodoc:
        def type
          :binary
        end

        def binary?
          true
        end

        def klass
          ::String
        end
      end
    end
  end
end
