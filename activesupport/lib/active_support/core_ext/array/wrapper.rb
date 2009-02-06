module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module Wrapper
        # Wraps the object in an Array unless it's an Array.
        def wrap(object)
          case object
          when nil
            []
          when self
            object
          else
            [object]
          end
        end
      end
    end
  end
end
