module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Time #:nodoc:
      # Enables the use of time calculations within Time itself
      module Calculations
        # Seconds since midnight: Time.now.seconds_since_midnight
        def seconds_since_midnight
          self.hour.hours + self.min.minutes + self.sec + (self.usec/1.0e+6)
        end
            
        # Returns a new Time where one or more of the elements have been changed according to the +options+ parameter. The time options
        # (hour, minute, sec, usec) reset cascadingly, so if only the hour is passed, then minute, sec, and usec is set to 0. If the hour and 
        # minute is passed, then sec and usec is set to 0.
        def change(options)
          ::Time.send(
            self.utc? ? :utc : :local, 
            options[:year]  || self.year, 
            options[:month] || self.month, 
            options[:mday]  || self.mday, 
            options[:hour]  || self.hour, 
            options[:min]   || (options[:hour] ? 0 : self.min),
            options[:sec]   || ((options[:hour] || options[:min]) ? 0 : self.sec),
            options[:usec]  || ((options[:hour] || options[:min] || options[:usec]) ? 0 : self.usec)
          )
        end

        # Returns a new Time representing the time a number of seconds ago, this is basically a wrapper around the Numeric extension
        # Do not use this method in combination with x.months, use months_ago instead!
        def ago(seconds)
          seconds.until(self)
        end

        # Returns a new Time representing the time a number of seconds since the instance time, this is basically a wrapper around 
        #the Numeric extension. Do not use this method in combination with x.months, use months_since instead!
        def since(seconds)
          seconds.since(self)
        end

        # Returns a new Time representing the time a number of specified months ago
        def months_ago(months)
          if months >= self.month 
            change(:year => self.year - 1, :month => 12).months_ago(months - self.month)
          else
            change(:year => self.year, :month => self.month - months)
          end
        end

        def months_since(months)
          if months + self.month > 12
            change(:year => self.year + 1, :month => 1).months_since(months - (self.month == 1 ? 12 : (self.month + 1)))
          else
            change(:year => self.year, :month => self.month + months)
          end
        end

        # Returns a new Time representing the "start" of this week (Monday, 0:00)
        def beginning_of_week
          (self - self.wday.days).midnight + 1.day
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
          self - self.seconds_since_midnight
        end
        alias :midnight :beginning_of_day
        alias :at_midnight :beginning_of_day
        alias :at_beginning_of_day :beginning_of_day
        
        # Returns a new Time representing the start of the month (1st of the month, 0:00)
        def beginning_of_month
          self - ((self.mday-1).days + self.seconds_since_midnight)
        end
        alias :at_beginning_of_month :beginning_of_month
        
        # Convenience method which returns a new Time representing the time 1 day ago
        def yesterday
          self.ago(1.day)
        end
        
        # Convenience method which returns a new Time representing the time 1 day since the instance time
        def tomorrow
          self.since(1.day)
        end
      end
    end
  end
end