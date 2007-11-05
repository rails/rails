require 'rational'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module DateTime #:nodoc:
      # Enables the use of time calculations within DateTime itself
      module Calculations
        def self.included(base) #:nodoc:
          base.extend ClassMethods
        end

        module ClassMethods
          # DateTimes aren't aware of DST rules, so use a consistent non-DST offset when creating a DateTime with an offset in the local zone
          def local_offset
            ::Time.local(2007).utc_offset.to_r / 86400
          end
        end

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
            options[:day]   || self.day,
            options[:hour]  || self.hour,
            options[:min]   || (options[:hour] ? 0 : self.min),
            options[:sec]   || ((options[:hour] || options[:min]) ? 0 : self.sec),
            options[:offset]  || self.offset,
            options[:start]  || self.start
          )
        end

        # Uses Date to provide precise Time calculations for years, months, and days.  The +options+ parameter takes a hash with
        # any of these keys: :years, :months, :weeks, :days, :hours, :minutes, :seconds.
        def advance(options)
          d = to_date.advance(options)
          datetime_advanced_by_date = change(:year => d.year, :month => d.month, :day => d.day)
          seconds_to_advance = (options[:seconds] || 0) + (options[:minutes] || 0) * 60 + (options[:hours] || 0) * 3600
          seconds_to_advance == 0 ? datetime_advanced_by_date : datetime_advanced_by_date.since(seconds_to_advance)
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
