module ActiveRecord
  module Type
    class Boolean < Value # :nodoc:
      def type
        :boolean
      end

      private

      def cast_value(value)
        if value == ''
          nil
        elsif ConnectionAdapters::Column::FALSE_VALUES.include?(value)
          false
        else
          true
        end
      end
    end
  end
end
