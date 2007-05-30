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
            options[:mday]  || self.mday,
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
          change(options.merge(:year => d.year, :month => d.month, :mday => d.day))
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

        # Returns a new DateTime representing the time a number of specified months ago
         def months_ago(months)
           months_since(-months)
         end

         def months_since(months)
           year, month, mday = self.year, self.month, self.mday

           month += months

           # in case months is negative
           while month < 1
             month += 12
             year -= 1
           end

           # in case months is positive
           while month > 12
             month -= 12
             year += 1
           end

           max = ::Time.days_in_month(month, year)
           mday = max if mday > max

           change(:year => year, :month => month, :mday => mday)
         end

         # Returns a new DateTime representing the time a number of specified years ago
         def years_ago(years)
           change(:year => self.year - years)
         end

         def years_since(years)
           change(:year => self.year + years)
         end

         # Short-hand for years_ago(1)
         def last_year
           years_ago(1)
         end

         # Short-hand for years_since(1)
         def next_year
           years_since(1)
         end

         # Short-hand for months_ago(1)
         def last_month
           months_ago(1)
         end

         # Short-hand for months_since(1)
         def next_month
           months_since(1)
         end

         # Returns a new DateTime representing the "start" of this week (Monday, 0:00)
         def beginning_of_week
           days_to_monday = self.wday!=0 ? self.wday-1 : 6
           (self - days_to_monday).midnight
         end
         alias :monday :beginning_of_week
         alias :at_beginning_of_week :beginning_of_week

         # Returns a new DateTime representing the start of the given day in next week (default is Monday).
         def next_week(day = :monday)
           days_into_week = { :monday => 0, :tuesday => 1, :wednesday => 2, :thursday => 3, :friday => 4, :saturday => 5, :sunday => 6}
           ((self + 7).beginning_of_week + days_into_week[day]).change(:hour => 0)
         end

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

         # Returns a new DateTime representing the start of the month (1st of the month, 0:00)
         def beginning_of_month
           change(:mday => 1,:hour => 0, :min => 0, :sec => 0)
         end
         alias :at_beginning_of_month :beginning_of_month

         # Returns a new DateTime representing the end of the month (last day of the month, 0:00)
         def end_of_month
           last_day = ::Time.days_in_month( self.month, self.year )
           change(:mday => last_day,:hour => 0, :min => 0, :sec => 0)
         end
         alias :at_end_of_month :end_of_month

         # Returns  a new DateTime representing the start of the quarter (1st of january, april, july, october, 0:00)
         def beginning_of_quarter
           beginning_of_month.change(:month => [10, 7, 4, 1].detect { |m| m <= self.month })
         end
         alias :at_beginning_of_quarter :beginning_of_quarter

         # Returns  a new DateTime representing the start of the year (1st of january, 0:00)
         def beginning_of_year
           change(:month => 1,:mday => 1,:hour => 0, :min => 0, :sec => 0)
         end
         alias :at_beginning_of_year :beginning_of_year

         # Convenience method which returns a new DateTime representing the time 1 day ago
         def yesterday
           self - 1
         end

         # Convenience method which returns a new DateTime representing the time 1 day since the instance time
         def tomorrow
           self + 1
         end
      end
    end
  end
end
