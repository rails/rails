module ActiveRecord
  module Type
    class Number < Object

      def boolean(value)
        value = cast(value)
        !(value.nil? || value.zero?)
      end

      def precast(value)
        convert_number_column_value(value)
      end

      private

      def convert_number_column_value(value)
        if value == false
          0
        elsif value == true
          1
        elsif value.is_a?(String) && value.blank?
          nil
        else
          value
        end
      end

    end
  end
end