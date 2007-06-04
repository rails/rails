module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Date #:nodoc:
      # Getting dates in different convenient string representations and other objects
      module Conversions
        DATE_FORMATS = {
          :short        => "%e %b",
          :long         => "%B %e, %Y",
          :db           => "%Y-%m-%d",
          :long_ordinal => lambda { |date| date.strftime("%B #{date.day.ordinalize}, %Y") }, # => "April 25th, 2007"
          :rfc822       => "%e %b %Y"
        }

        def self.included(klass) #:nodoc:
          klass.send(:alias_method, :to_default_s, :to_s)
          klass.send(:alias_method, :to_s, :to_formatted_s)
          klass.send(:alias_method, :default_inspect, :inspect)
          klass.send(:alias_method, :inspect, :readable_inspect)          
        end

        def to_formatted_s(format = :default)
          if formatter = DATE_FORMATS[format]
            if formatter.respond_to?(:call)
              formatter.call(self).to_s
            else
              strftime(formatter).strip
            end
          else
            to_default_s
          end
        end
        
        # Overrides the default inspect method with a human readable one, e.g., "Mon, 21 Feb 2005"
        def readable_inspect
          strftime("%a, %d %b %Y")
        end

        # To be able to keep Times, Dates and DateTimes interchangeable on conversions
        def to_date
          self
        end

        # Converts self to a Ruby Time object; time is set to beginning of day
        # Timezone can either be :local or :utc  (default :local)
        def to_time(form = :local)
          ::Time.send("#{form}_time", year, month, day)
        end
        
        # Converts self to a Ruby DateTime object; time is set to beginning of day
        def to_datetime
          ::DateTime.civil(year, month, day, 0, 0, 0, 0, 0)
        end

        def xmlschema
          to_time.xmlschema
        end
      end
    end
  end
end
