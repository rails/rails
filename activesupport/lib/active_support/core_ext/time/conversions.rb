module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Time #:nodoc:
      # Getting times in different convenient string representations and other objects
      module Conversions
        def self.append_features(klass)
          super
          klass.send(:alias_method, :to_default_s, :to_s)
          klass.send(:alias_method, :to_s, :to_formatted_s)
        end
        
        def to_formatted_s(format = :default)
          case format
            when :default then to_default_s
            when :db      then strftime("%Y-%m-%d %H:%M:%S")
            when :short   then strftime("%e %b %H:%M").strip
            when :long    then strftime("%e %B, %Y %H:%M").strip
          end
        end

        def to_date
          Date.new(year, month, day)
        end

        # To be able to keep Dates and Times interchangeable on conversions
        def to_time
          self
        end
      end
    end
  end
end