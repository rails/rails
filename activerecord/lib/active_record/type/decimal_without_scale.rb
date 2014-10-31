require 'active_record/type/big_integer'

module ActiveRecord
  module Type
    class DecimalWithoutScale < BigInteger # :nodoc:
      def type
        :decimal
      end
    end
  end
end
