module ActiveRecord
  module ConnectionAdapters
    module Type
      module Numeric # :nodoc:
        def number?
          true
        end
      end
    end
  end
end
