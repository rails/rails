module ActiveRecord
  module Type
    class Time < Value # :nodoc:
      include TimeValue

      def type
        :time
      end

      private

      def cast_value(value)
        return value unless value.is_a?(::String)
        return if value.empty?

        dummy_time_value = "2000-01-01 #{value}"

        fast_string_to_time(dummy_time_value) || begin
          time_hash = ::Date._parse(dummy_time_value)
          return if time_hash[:hour].nil?
          new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction))
        end
      end
    end
  end
end
