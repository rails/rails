require 'active_support/duration'

module ActiveSupport
  module DateAndTime
    module WithDuration #:nodoc:
      def +(other) #:nodoc:
        if ActiveSupport::Duration === other
          other.since(self)
        else
          super
        end
      end

      def -(other) #:nodoc:
        if ActiveSupport::Duration === other
          self + (-other)
        else
          super
        end
      end
    end
  end
end
