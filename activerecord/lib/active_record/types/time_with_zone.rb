module ActiveRecord
  module Type
    class TimeWithZone < Object

      def cast(time)
        time = super(time)
        time.acts_like?(:time) ? time.in_time_zone : time
      end

      def precast(time)
        unless time.acts_like?(:time)
          time = time.is_a?(String) ? ::Time.zone.parse(time) : time.to_time rescue time
        end
        time = time.in_time_zone rescue nil if time
        super(time)
      end

    end
  end
end
