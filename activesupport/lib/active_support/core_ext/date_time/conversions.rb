module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module DateTime #:nodoc:
      # Getting datetimes in different convenient string representations and other objects
      module Conversions
        def self.included(klass)
          klass.send(:alias_method, :to_datetime_default_s, :to_s)
          klass.send(:alias_method, :to_s, :to_formatted_s)
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
