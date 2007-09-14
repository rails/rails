module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Float #:nodoc:
      module Rounding
        def self.included(base) #:nodoc:
          base.class_eval do
            alias_method :round_without_precision, :round
            alias_method :round, :round_with_precision
          end
        end

        # Rounds the float with the specified precision.
        #
        #   x = 1.337
        #   x.round    # => 1
        #   x.round(1) # => 1.3
        #   x.round(2) # => 1.34
        def round_with_precision(precision = nil)
          precision.nil? ? round_without_precision : (self * (10 ** precision)).round / (10 ** precision).to_f
        end
      end
    end
  end
end
