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

          # Returns a new Date where one or more of the elements have been changed according to the +options+ parameter.
          #
          # Examples:
          #
          #   Date.new(2007, 5, 12).change(:day => 1)                  # => Date.new(2007, 5, 12)
          #   Date.new(2007, 5, 12).change(:year => 2005, :month => 1) # => Date.new(2005, 1, 12)
          def change(options)
            ::Date.new(
              options[:year]  || self.year,
              options[:month] || self.month,
              options[:day]   || options[:mday] || self.day # mday is deprecated
            )
          end
        end
      end
    end
  end
end