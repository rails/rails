module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Time #:nodoc:
      # Getting times in different convenient string representations and other objects
      module Conversions
        DATE_FORMATS = {
          :db     => "%Y-%m-%d %H:%M:%S",
          :short  => "%d %b %H:%M",
          :long   => "%B %d, %Y %H:%M",
          :rfc822 => "%a, %d %b %Y %H:%M:%S %z"
        }

        def self.included(klass)
          klass.send(:alias_method, :to_default_s, :to_s)
          klass.send(:alias_method, :to_s, :to_formatted_s)
        end
        
        def to_formatted_s(format = :default)
          DATE_FORMATS[format] ? strftime(DATE_FORMATS[format]).strip : to_default_s          
        end

        def to_date
          ::Date.new(year, month, day)
        end

        # To be able to keep Dates and Times interchangeable on conversions
        def to_time
          self
        end
      end
    end
  end
end
