module ActiveRecord::ConnectionAdapters::Type
  class Time < Value
    include TimeValue

    def type
      :time
    end

    def parse_string(string)
      dummy_time_string = "2000-01-01 #{string}"

      fast_string_to_time(dummy_time_string) || begin
        time_hash = ::Date._parse(dummy_time_string)
        return nil if time_hash[:hour].nil?
        new_time(*time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction))
      end
    end
  end
end
