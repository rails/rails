module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Numeric #:nodoc:
      # Enables the use of time calculations and declarations, like 45.minutes + 2.hours + 4.years.
      #
      # These methods use Time#advance for precise date calculations when using from_now, ago, etc. 
      # as well as adding or subtracting their results from a Time object. For example:
      #
      #   # equivalent to Time.now.advance(:months => 1)
      #   1.month.from_now
      #
      #   # equivalent to Time.now.advance(:years => 2)
      #   2.years.from_now
      #
      #   # equivalent to Time.now.advance(:months => 4, :years => 5)
      #   (4.months + 5.years).from_now
      # 
      # While these methods provide precise calculation when used as in the examples above, care
      # should be taken to note that this is not true if the result of `months', `years', etc is
      # converted before use:
      #
      #   # equivalent to 30.days.to_i.from_now
      #   1.month.to_i.from_now
      #
      #   # equivalent to 365.25.days.to_f.from_now
      #   1.year.to_f.from_now
      #
      # In such cases, Ruby's core 
      # Date[http://stdlib.rubyonrails.org/libdoc/date/rdoc/index.html] and 
      # Time[http://stdlib.rubyonrails.org/libdoc/time/rdoc/index.html] should be used for precision
      # date and time arithmetic
      module Time
        def seconds
          ActiveSupport::Duration.new(self, [[:seconds, self]])
        end
        alias :second :seconds

        def minutes
          ActiveSupport::Duration.new(self * 60, [[:seconds, self * 60]])
        end
        alias :minute :minutes  
        
        def hours
          ActiveSupport::Duration.new(self * 3600, [[:seconds, self * 3600]])
        end
        alias :hour :hours
        
        def days
          ActiveSupport::Duration.new(self * 24.hours, [[:days, self]])
        end
        alias :day :days

        def weeks
          ActiveSupport::Duration.new(self * 7.days, [[:days, self * 7]])
        end
        alias :week :weeks
        
        def fortnights
          ActiveSupport::Duration.new(self * 2.weeks, [[:days, self * 14]])
        end
        alias :fortnight :fortnights
        
        # Reads best without arguments:  10.minutes.ago
        def ago(time = ::Time.now)
          time - self
        end

        # Reads best with argument:  10.minutes.until(time)
        alias :until :ago

        # Reads best with argument:  10.minutes.since(time)
        def since(time = ::Time.now)
          time + self
        end

        # Reads best without arguments:  10.minutes.from_now
        alias :from_now :since
      end
    end
  end
end
