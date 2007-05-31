module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Time #:nodoc:
      # Enables the use of time calculations within Time itself
      module Calculations
        def self.included(base) #:nodoc:
          base.extend(ClassMethods)

          base.send(:alias_method, :plus_without_duration, :+)
          base.send(:alias_method, :+, :plus_with_duration)
          base.send(:alias_method, :minus_without_duration, :-)
          base.send(:alias_method, :-, :minus_with_duration)
        end

        module ClassMethods
          # Return the number of days in the given month. If a year is given,
          # February will return the correct number of days for leap years.
          # Otherwise, this method will always report February as having 28
          # days.
          def days_in_month(month, year=nil)
            if month == 2
              !year.nil? && (year % 4 == 0) && ((year % 100 != 0) || (year % 400 == 0)) ?  29 : 28
            elsif month <= 7
              month % 2 == 0 ? 30 : 31
            else
              month % 2 == 0 ? 31 : 30
            end
          end

          # Returns a new Time if requested year can be accomodated by Ruby's Time class
          # (i.e., if year is within either 1970..2038 or 1902..2038, depending on system architecture);
          # otherwise returns a DateTime
          def time_with_datetime_fallback(utc_or_local, year, month=1, day=1, hour=0, min=0, sec=0, usec=0)
            ::Time.send(utc_or_local, year, month, day, hour, min, sec, usec)
          rescue
            offset = if utc_or_local.to_sym == :utc then 0 else ::DateTime.now.offset end
            ::DateTime.civil(year, month, day, hour, min, sec, offset, 0)
          end

          # wraps class method time_with_datetime_fallback with utc_or_local == :utc
          def utc_time(*args)
            time_with_datetime_fallback(:utc, *args)
          end

          # wraps class method time_with_datetime_fallback with utc_or_local == :local
          def local_time(*args)
            time_with_datetime_fallback(:local, *args)
          end
        end

        # Seconds since midnight: Time.now.seconds_since_midnight
        def seconds_since_midnight
          self.to_i - self.change(:hour => 0).to_i + (self.usec/1.0e+6)
        end

        # Returns a new Time where one or more of the elements have been changed according to the +options+ parameter. The time options
        # (hour, minute, sec, usec) reset cascadingly, so if only the hour is passed, then minute, sec, and usec is set to 0. If the hour and
        # minute is passed, then sec and usec is set to 0.
        def change(options)
          ::Time.send(
            self.utc? ? :utc_time : :local_time,
            options[:year]  || self.year,
            options[:month] || self.month,
            options[:day]   || options[:mday] || self.day, # mday is deprecated
            options[:hour]  || self.hour,
            options[:min]   || (options[:hour] ? 0 : self.min),
            options[:sec]   || ((options[:hour] || options[:min]) ? 0 : self.sec),
            options[:usec]  || ((options[:hour] || options[:min] || options[:sec]) ? 0 : self.usec)
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

        # Returns a new Time representing the time a number of seconds ago, this is basically a wrapper around the Numeric extension
        # Do not use this method in combination with x.months, use months_ago instead!
        def ago(seconds)
          self.since(-seconds)
        end

        # Returns a new Time representing the time a number of seconds since the instance time, this is basically a wrapper around
        #the Numeric extension. Do not use this method in combination with x.months, use months_since instead!
        def since(seconds)
          initial_dst = self.dst? ? 1 : 0
          f = seconds.since(self)
          final_dst   = f.dst? ? 1 : 0
          (seconds.abs >= 86400 && initial_dst != final_dst) ? f + (initial_dst - final_dst).hours : f
        rescue
          self.to_datetime.since(seconds)          
        end
        alias :in :since

        # Returns a new Time representing the time a number of specified months ago
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

        # Returns a new Time representing the time a number of specified years ago
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

        # Returns a new Time representing the "start" of this week (Monday, 0:00)
        def beginning_of_week
          days_to_monday = self.wday!=0 ? self.wday-1 : 6
          (self - days_to_monday.days).midnight
        end
        alias :monday :beginning_of_week
        alias :at_beginning_of_week :beginning_of_week

        # Returns a new Time representing the start of the given day in next week (default is Monday).
        def next_week(day = :monday)
          days_into_week = { :monday => 0, :tuesday => 1, :wednesday => 2, :thursday => 3, :friday => 4, :saturday => 5, :sunday => 6}
          since(1.week).beginning_of_week.since(days_into_week[day].day).change(:hour => 0)
        end

        # Returns a new Time representing the start of the day (0:00)
        def beginning_of_day
          (self - self.seconds_since_midnight).change(:usec => 0)
        end
        alias :midnight :beginning_of_day
        alias :at_midnight :beginning_of_day
        alias :at_beginning_of_day :beginning_of_day

        # Returns a new Time representing the end of the day (23:59:59)
        def end_of_day
          change(:hour => 23, :min => 59, :sec => 59)
        end

        # Returns a new Time representing the start of the month (1st of the month, 0:00)
        def beginning_of_month
          #self - ((self.mday-1).days + self.seconds_since_midnight)
          change(:mday => 1,:hour => 0, :min => 0, :sec => 0, :usec => 0)
        end
        alias :at_beginning_of_month :beginning_of_month

        # Returns a new Time representing the end of the month (last day of the month, 0:00)
        def end_of_month
          #self - ((self.mday-1).days + self.seconds_since_midnight)
          last_day = ::Time.days_in_month( self.month, self.year )
          change(:mday => last_day,:hour => 0, :min => 0, :sec => 0, :usec => 0)
        end
        alias :at_end_of_month :end_of_month
		
        # Returns  a new Time representing the start of the quarter (1st of january, april, july, october, 0:00)
        def beginning_of_quarter
          beginning_of_month.change(:month => [10, 7, 4, 1].detect { |m| m <= self.month })
        end
        alias :at_beginning_of_quarter :beginning_of_quarter

        # Returns  a new Time representing the start of the year (1st of january, 0:00)
        def beginning_of_year
          change(:month => 1,:mday => 1,:hour => 0, :min => 0, :sec => 0, :usec => 0)
        end
        alias :at_beginning_of_year :beginning_of_year

        # Convenience method which returns a new Time representing the time 1 day ago
        def yesterday
          self.ago(1.day)
        end

        # Convenience method which returns a new Time representing the time 1 day since the instance time
        def tomorrow
          self.since(1.day)
        end

        def plus_with_duration(other) #:nodoc:
          if ActiveSupport::Duration === other
            other.since(self)
          else
            plus_without_duration(other)
          end
        end

        def minus_with_duration(other) #:nodoc:
          if ActiveSupport::Duration === other
            other.until(self)
          else
            minus_without_duration(other)
          end
        end
      end
    end
  end
end
