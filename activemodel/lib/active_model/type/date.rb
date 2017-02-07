module ActiveModel
  module Type
    class Date < Value # :nodoc:
      include Helpers::AcceptsMultiparameterTime.new

      def type
        :date
      end

      def serialize(value)
        cast(value)
      end

      def type_cast_for_schema(value)
        "'#{value.to_s(:db)}'"
      end

      private

        def cast_value(value)
          if value.is_a?(::String)
            return if value.empty?
            string_to_date(value)
          elsif value.respond_to?(:to_date)
            value.to_date
          else
            value
          end
        end

        def string_to_date(value)
          parse_with_format(value, "%m/%d/%Y") ||
              parse_with_format(value, "%d/%m/%Y") ||
              parse_with_format(value, "%Y-%m-%d")
        end

        def parse_with_format(value, format)
          ::Date.strptime(value, format) rescue nil
        end

        def value_from_multiparameter_assignment(*)
          time = super
          time && time.to_date
        end
    end
  end
end
