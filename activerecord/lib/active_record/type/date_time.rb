module ActiveRecord
  module Type
    class DateTime < Value # :nodoc:
      include TimeValue

      def type
        :datetime
      end

      def type_cast_for_database(value)
        return super unless value.acts_like?(:time)

        zone_conversion_method = ActiveRecord::Base.default_timezone == :utc ? :getutc : :getlocal

        if value.respond_to?(zone_conversion_method)
          value = value.send(zone_conversion_method)
        end

        return value unless has_precision?

        result = value.to_s(:db)
        if value.respond_to?(:usec) && (1..6).cover?(precision)
          "#{result}.#{sprintf("%0#{precision}d", value.usec / 10 ** (6 - precision))}"
        else
          result
        end
      end

      private

      alias has_precision? precision

      def cast_value(string)
        return string unless string.is_a?(::String)
        return if string.empty?

        fast_string_to_time(string) || fallback_string_to_time(string)
      end

      # '0.123456' -> 123456
      # '1.123456' -> 123456
      def microseconds(time)
        time[:sec_fraction] ? (time[:sec_fraction] * 1_000_000).to_i : 0
      end

      def fallback_string_to_time(string)
        time_hash = ::Date._parse(string)
        time_hash[:sec_fraction] = microseconds(time_hash)

        new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset))
      end
    end
  end
end
