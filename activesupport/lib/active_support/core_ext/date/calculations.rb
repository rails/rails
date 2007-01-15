module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Date #:nodoc:
      # Enables the use of time calculations within Time itself
      module Calculations
        def self.included(base) #:nodoc:
          base.send(:include, ClassMethods)
          
          base.send(:alias_method, :plus_without_duration, :+)
          base.send(:alias_method, :+, :plus_with_duration)
          
          base.send(:alias_method, :minus_without_duration, :-)
          base.send(:alias_method, :-, :minus_with_duration)
        end

        module ClassMethods
          def plus_with_duration(other) #:nodoc:
            if ActiveSupport::Duration === other
              other.since(self)
            else
              plus_without_duration(other)
            end
          end
          
          def minus_with_duration(other) #:nodoc:
            if ActiveSupport::Duration === other
              plus_with_duration(-other)
            else
              minus_without_duration(other)
            end
          end
          
          # Provides precise Date calculations for years, months, and days.  The +options+ parameter takes a hash with 
          # any of these keys: :months, :days, :years.
          def advance(options)
            d = ::Date.new(year + (options.delete(:years) || 0), month, day)
            d = d >> options.delete(:months) if options[:months]
            d = d + options.delete(:days) if options[:days]
            d
          end
        end
      end
    end
  end
end