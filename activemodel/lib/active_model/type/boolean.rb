module ActiveModel
  module Type
    class Boolean < Value # :nodoc:
      FALSE_VALUES = [false, 0, '0', 'f', 'F', 'false', 'FALSE', 'off', 'OFF'].to_set

      def type
        :boolean
      end

      private

      def cast_value(value)
        if value == ''
          nil
        else
          !FALSE_VALUES.include?(value)
        end
      end
    end
  end
end
