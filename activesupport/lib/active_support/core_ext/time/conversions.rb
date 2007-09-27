module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Time #:nodoc:
      # Getting times in different convenient string representations and other objects
      module Conversions
        DATE_FORMATS = {
          :db           => "%Y-%m-%d %H:%M:%S",
          :time         => "%H:%M",
          :short        => "%d %b %H:%M",
          :long         => "%B %d, %Y %H:%M",
          :long_ordinal => lambda { |time| time.strftime("%B #{time.day.ordinalize}, %Y %H:%M") },
          :rfc822       => "%a, %d %b %Y %H:%M:%S %z"
        }

        def self.included(base)
          base.class_eval do
            alias_method :to_default_s, :to_s
            alias_method :to_s, :to_formatted_s
          end
        end

        def to_formatted_s(format = :default)
          if formatter = DATE_FORMATS[format]
            if formatter.respond_to?(:call)
              formatter.call(self).to_s
            else
              strftime(formatter)
            end
          else
            to_default_s
          end
        end

        # Converts self to a Ruby Date object; time portion is discarded
        def to_date
          ::Date.new(year, month, day)
        end

        # To be able to keep Times, Dates and DateTimes interchangeable on conversions
        def to_time
          self
        end

        # converts to a Ruby DateTime instance; preserves utc offset
        def to_datetime
          ::DateTime.civil(year, month, day, hour, min, sec, Rational(utc_offset, 86400), 0)
        end
      end
    end
  end
end
