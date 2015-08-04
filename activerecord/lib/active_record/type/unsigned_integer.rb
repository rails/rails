module ActiveRecord
  module Type
    class UnsignedInteger < Integer # :nodoc:
      private

      def max_value
        super * 2
      end

      def min_value
        0
      end
    end
  end
end
