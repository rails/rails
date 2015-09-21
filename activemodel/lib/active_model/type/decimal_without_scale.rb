require 'active_model/type/big_integer'

module ActiveModel
  module Type
    class DecimalWithoutScale < BigInteger # :nodoc:
      def type
        :decimal
      end
    end
  end
end
