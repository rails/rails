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
        else value.to_i rescue nil
        end
      end
    end
  end
end
