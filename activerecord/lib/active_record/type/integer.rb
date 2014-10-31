module ActiveRecord
  module Type
    class Integer < Value # :nodoc:
      include Numeric

      def type
        :integer
      end

      alias type_cast_for_database type_cast

      private

      def cast_value(value)
        case value
        when true then 1
        when false then 0
        else
          result = value.to_i rescue nil
          ensure_below_max(result) if result
          result
        end
      end

      def ensure_below_max(value)
        if value > max_value
          raise RangeError, "#{value} is too large for #{self.class} with limit #{limit || 4}"
        end
      end

      def max_value
        @max_value = determine_max_value unless defined?(@max_value)
        @max_value
      end

      def determine_max_value
        limit = self.limit || 4
        2 << (limit * 8 - 1) # 8 bits per byte with one bit for sign
      end
    end
  end
end
