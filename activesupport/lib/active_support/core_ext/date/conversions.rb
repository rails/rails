module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Date #:nodoc:
      # Getting dates in different convenient string representations and other objects
      module Conversions
        def self.append_features(klass)
          super
          klass.send(:alias_method, :to_default_s, :to_s)
          klass.send(:alias_method, :to_s, :to_formatted_s)
        end
        
        def to_formatted_s(format = :default)
          case format
            when :default then to_default_s
            when :short   then strftime("%e %b").strip
            when :long    then strftime("%B %e, %Y").strip
          end
        end

        # To be able to keep Dates and Times interchangeable on conversions
        def to_date
          self
        end

        def to_time(form = :local)
          ::Time.send(form, year, month, day)
        end
      end
    end
  end
end