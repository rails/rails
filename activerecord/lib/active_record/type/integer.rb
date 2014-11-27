module ActiveRecord
  module Type
    class Integer < Value # :nodoc:
      include Numeric

      def initialize(*)
        super
        @range = min_value...max_value
      end

      def type
        :integer
      end

      alias type_cast_for_database type_cast

      def type_cast_from_database(value)
        return if value.nil?
        value.to_i
      end

      protected

      attr_reader :range

      private

      def cast_value(value)
        case value
        when true then 1
        when false then 0
        else
          result = value.to_i rescue nil
          ensure_in_range(result) if result
          result
        end
      end

      def ensure_in_range(value)
        unless range.cover?(value)
          raise RangeError, "#{value} is out of range for #{self.class} with limit #{limit || 4}"
        end
      end

      def max_value
        limit = self.limit || 4
        1 << (limit * 8 - 1) # 8 bits per byte with one bit for sign
      end

      def min_value
        -max_value
      end
    end
  end
end
