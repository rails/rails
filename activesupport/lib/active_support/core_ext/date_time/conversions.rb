module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module DateTime #:nodoc:
      # Getting datetimes in different convenient string representations and other objects
      module Conversions
        DATE_FORMATS = {
          :db     => "%Y-%m-%d %H:%M:%S",
          :time   => "%H:%M",
          :short  => "%d %b %H:%M",
          :long   => "%B %d, %Y %H:%M",
          :long_ordinal => lambda { |datetime| datetime.strftime("%B #{datetime.day.ordinalize}, %Y %H:%M") },
          :rfc822 => "%a, %d %b %Y %H:%M:%S %z",
        }

        def self.included(klass)
          klass.send(:alias_method, :to_datetime_default_s, :to_s)
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
            to_datetime_default_s
          end
        end

        def to_date
          ::Date.new(year, month, day)
        end

        # To be able to keep Times and DateTimes interchangeable on conversions
        def to_datetime
          self
        end
      end
    end
  end
end
