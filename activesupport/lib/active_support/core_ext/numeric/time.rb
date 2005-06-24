module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Numeric #:nodoc:
      # Enables the use of time calculations and declarations, like 45.minutes + 2.hours + 4.years
      module Time
        def minutes
          self * 60
        end
        alias :minute :minutes  
        
        def hours
          self * 60.minutes
        end
        alias :hour :hours
        
        def days
          self * 24.hours
        end
        alias :day :days

        def weeks
          self * 7.days
        end
        alias :week :weeks
        
        def fortnights
          self * 2.weeks
        end
        alias :fortnight :fortnights
        
        def months
          self * 30.days
        end
        alias :month :months

        def years
          (self * 365.25.days).to_i
        end
        alias :year :years

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
