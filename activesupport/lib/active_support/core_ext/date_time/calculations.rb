require 'rational'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module DateTime #:nodoc:
      # Enables the use of time calculations within DateTime itself
      module Calculations

        # Seconds since midnight: DateTime.now.seconds_since_midnight
        def seconds_since_midnight
          self.sec + (self.min * 60) + (self.hour * 3600)
        end

        # Returns a new DateTime where one or more of the elements have been changed according to the +options+ parameter. The time options
        # (hour, minute, sec) reset cascadingly, so if only the hour is passed, then minute and sec is set to 0. If the hour and
        # minute is passed, then sec is set to 0.
        def change(options)
          ::DateTime.civil(
            options[:year]  || self.year,
            options[:month] || self.month,
            options[:day]   || options[:mday] || self.day, # mday is deprecated
            options[:hour]  || self.hour,
            options[:min]   || (options[:hour] ? 0 : self.min),
            options[:sec]   || ((options[:hour] || options[:min]) ? 0 : self.sec),
            options[:offset]  || self.offset,
            options[:start]  || self.start
          )
        end

        # Uses Date to provide precise Time calculations for years, months, and days.  The +options+ parameter takes a hash with
        # any of these keys: :months, :days, :years.
        def advance(options)
          d = ::Date.new(year + (options.delete(:years) || 0), month, day)
          d = d >> options.delete(:months) if options[:months]
          d = d +  options.delete(:days)   if options[:days]
          change(options.merge(:year => d.year, :month => d.month, :day => d.day))
        end

        # Returns a new DateTime representing the time a number of seconds ago
        # Do not use this method in combination with x.months, use months_ago instead!
        def ago(seconds)
          self.since(-seconds)
        end

        # Returns a new DateTime representing the time a number of seconds since the instance time
        # Do not use this method in combination with x.months, use months_since instead!
        def since(seconds)
          self + Rational(seconds.round, 86400)
        end
        alias :in :since

        # Returns a new DateTime representing the start of the day (0:00)
        def beginning_of_day
          change(:hour => 0)
        end
        alias :midnight :beginning_of_day
        alias :at_midnight :beginning_of_day
        alias :at_beginning_of_day :beginning_of_day

        # Returns a new DateTime representing the end of the day (23:59:59)
        def end_of_day
          change(:hour => 23, :min => 59, :sec => 59)
        end
      end
    end
  end
end
