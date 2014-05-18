module ActiveRecord
  module ConnectionAdapters
    module Type
      class Timestamp < Value # :nodoc:
        include TimeValue

        def type
          :timestamp
        end

        private

        def cast_value(value)
          return value unless value.is_a?(::String)
          return if value.empty?

          fast_string_to_time(value) || fallback_string_to_time(value)
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
  end
end
