module ActiveRecord
  module Type
    # Useful for handling attributes not mapped to types. Performs some boolean typecasting,
    # but otherwise leaves the value untouched.
    class Unknown

      def cast(value)
        value
      end

      def precast(value)
        value
      end

      # Attempts typecasting to handle numeric, false and blank values.
      def boolean(value)
        empty = (numeric?(value) && value.to_i.zero?) || false?(value) || value.blank?
        !empty
      end

      def appendable?
        false
      end

      protected

      def false?(value)
        ActiveRecord::ConnectionAdapters::Column::FALSE_VALUES.include?(value)
      end

      def numeric?(value)
        Numeric === value || value !~ /[^0-9]/
      end

    end
  end
end