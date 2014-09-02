require 'active_record/type/integer'

module ActiveRecord
  module Type
    class DecimalWithoutScale < Integer # :nodoc:
      def type
        :decimal
      end
    end
  end
end
