require 'active_record/connection_adapters/type/integer'

module ActiveRecord
  module ConnectionAdapters
    module Type
      class DecimalWithoutScale < Integer # :nodoc:
        def type
          :decimal
        end
      end
    end
  end
end
