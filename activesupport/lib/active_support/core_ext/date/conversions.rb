module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Date #:nodoc:
      # Getting dates in different convenient string representations and other objects
      module Conversions
        DATE_FORMATS = {
          :short => "%e %b",
          :long  => "%B %e, %Y"
        }

        def self.included(klass) #:nodoc:
          klass.send(:alias_method, :to_default_s, :to_s)
          klass.send(:alias_method, :to_s, :to_formatted_s)
        end

        def to_formatted_s(format = :default)
          DATE_FORMATS[format] ? strftime(DATE_FORMATS[format]).strip : to_default_s
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
