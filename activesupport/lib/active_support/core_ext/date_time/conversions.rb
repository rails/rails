module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module DateTime #:nodoc:
      # Getting datetimes in different convenient string representations and other objects
      module Conversions
        def self.included(base)
          base.class_eval do
            alias_method :to_datetime_default_s, :to_s
            alias_method :to_s, :to_formatted_s
            alias_method :default_inspect, :inspect
            alias_method :inspect, :readable_inspect
          end
        end

        def to_formatted_s(format = :default)
          if formatter = ::Time::DATE_FORMATS[format]
            if formatter.respond_to?(:call)
              formatter.call(self).to_s
            else
              strftime(formatter)
            end
          else
            to_datetime_default_s
          end
        end

        # Overrides the default inspect method with a human readable one, e.g., "Mon, 21 Feb 2005 14:30:00 +0000"
        def readable_inspect
          to_s(:rfc822)
        end

        # Converts self to a Ruby Date object; time portion is discarded
        def to_date
          ::Date.new(year, month, day)
        end

        # Attempts to convert self to a Ruby Time object; returns self if out of range of Ruby Time class
        # If self has an offset other than 0, self will just be returned unaltered, since there's no clean way to map it to a Time
        def to_time
          self.offset == 0 ? ::Time.utc_time(year, month, day, hour, min, sec) : self
        end        

        # To be able to keep Times, Dates and DateTimes interchangeable on conversions
        def to_datetime
          self
        end
        
        def xmlschema
          strftime("%Y-%m-%dT%H:%M:%S#{offset == 0 ? 'Z' : '%Z'}")
        end
      end
    end
  end
end
