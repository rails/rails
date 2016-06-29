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
          fast_string_to_date(value) || fallback_string_to_date(value)
        elsif value.respond_to?(:to_date)
          value.to_date
        else
          value
        end
      end

      ISO_DATE = /\A(\d{4})-(\d\d)-(\d\d)\z/
      def fast_string_to_date(string)
        if string =~ ISO_DATE
          new_date $1.to_i, $2.to_i, $3.to_i
        end
      end

      def fallback_string_to_date(string)
        new_date(*::Date._parse(string, false).values_at(:year, :mon, :mday))
      end

      def new_date(year, mon, mday)
        if year && year != 0
          ::Date.new(year, mon, mday) rescue nil
        end
      end

      def value_from_multiparameter_assignment(*)
        time = super
        time && time.to_date
      end
    end
  end
end
