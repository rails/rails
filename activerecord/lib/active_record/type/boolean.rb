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
        else
          !ConnectionAdapters::Column::FALSE_VALUES.include?(value)
        end
      end
    end
  end
end
