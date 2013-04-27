module ActiveSupport
  class TimeChanger #:nodoc:
    attr_accessor :time, :options

    def initialize(time, options)
      @time = time
      @options = options

      default_options!
    end

    def change
      if time.utc?
        as_utc
      elsif time.zone
        as_zone
      else
        as_standard
      end
    end

    private

      def as_utc
        ::Time.utc(*gather_options)
      end

      def as_zone
        ::Time.local(*gather_options)
      end

      def as_standard
        ::Time.new(*gather_standard_options)
      end

      def default_options!
        options[:usec] ||= default_usec
        options[:sec] ||= default_sec
        options[:min] ||= default_min
        options[:hour] ||= time.hour
        options[:day] ||= time.day
        options[:month] ||= time.month
        options[:year] ||= time.year
      end

      def gather_options
        options.values_at(:year, :month, :day, :hour, :min, :sec, :usec)
      end

      def gather_standard_options
        options.values_at(:year, :month, :day, :hour, :min) <<
          options[:sec] + (options[:usec].to_r / 1000000) <<
          time.utc_offset
      end

      def default_min
        options[:hour] ? 0 : time.min
      end

      def default_sec
        (options[:hour] || options[:min]) ? 0 : time.sec
      end

      def default_usec
        (options[:hour] || options[:min] || options[:sec]) ? 0 : Rational(time.nsec, 1000)
      end
  end
end
