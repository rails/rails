require 'active_record/type/integer'

module ActiveRecord
  module Type
    class BigInteger < Integer # :nodoc:
      private

      def max_value
        ::Float::INFINITY
      end
    end
  end
end
