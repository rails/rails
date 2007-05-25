module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Date #:nodoc:
      # Getting dates in different convenient string representations and other objects
      module Conversions
        DATE_FORMATS = {
          :short        => "%e %b",
          :long         => "%B %e, %Y",
          :db           => "%Y-%m-%d",
          :long_ordinal => lambda { |date| date.strftime("%B #{date.day.ordinalize}, %Y") } # => "April 25th, 2007"
        }

        def self.included(klass) #:nodoc:
          klass.send(:alias_method, :to_default_s, :to_s)
          klass.send(:alias_method, :to_s, :to_formatted_s)
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

        # To be able to keep Dates and Times interchangeable on conversions
        def to_date
          self
        end

        def to_time(form = :local)
          if respond_to?(:hour)
            ::Time.send(form, year, month, day, hour, min, sec)
          else
            ::Time.send(form, year, month, day)
          end
        end

        def xmlschema
          to_time.xmlschema
        end
      end
    end
  end
end
