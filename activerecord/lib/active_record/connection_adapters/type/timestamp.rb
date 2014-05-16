module ActiveRecord::ConnectionAdapters::Type
  class Timestamp < Value
    include TimeValue

    def type
      :timestamp
    end

    def parse_string(string)
      fast_string_to_time(string) || fallback_string_to_time(string)
    end

    private

      def fallback_string_to_time(string)
        time_hash = ::Date._parse(string)
        time_hash[:sec_fraction] = microseconds(time_hash)

        new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset))
      end

      # '0.123456' -> 123456
      # '1.123456' -> 123456
      def microseconds(time)
        time[:sec_fraction] ? (time[:sec_fraction] * 1_000_000).to_i : 0
      end
  end
end
