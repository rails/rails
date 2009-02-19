module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module Wrapper
        # Wraps the object in an Array unless it's an Array.  Converts the
        # object to an Array using #to_ary if it implements that.
        def wrap(object)
          case object
          when nil
            []
          when self
            object
          else
            if object.respond_to?(:to_ary)
              object.to_ary
            else
              [object]
            end
          end
        end
      end
    end
  end
end
