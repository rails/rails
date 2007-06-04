module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module DateTime #:nodoc:
      # Getting datetimes in different convenient string representations and other objects
      module Conversions
        def self.included(klass)
          klass.send(:alias_method, :to_datetime_default_s, :to_s)
          klass.send(:alias_method, :to_s, :to_formatted_s)
          klass.send(:alias_method, :default_inspect, :inspect)
          klass.send(:alias_method, :inspect, :readable_inspect)
        end

        def to_formatted_s(format = :default)
          if formatter = ::Time::DATE_FORMATS[format]
            if formatter.respond_to?(:call)
              formatter.call(self).to_s
            else
              strftime(formatter).strip
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
        # If self.offset is 0, then will attempt to cast as a utc time; otherwise will attempt to cast in local time zone
        def to_time
          method = if self.offset == 0 then 'utc' else 'local' end
          ::Time.send(method, year, month, day, hour, min, sec) rescue self
        end        

        # To be able to keep Times, Dates and DateTimes interchangeable on conversions
        def to_datetime
          self
        end
      end
    end
  end
end
