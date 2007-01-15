module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Time #:nodoc:
      module Behavior
        # Enable more predictable duck-typing on Time-like classes. See
        # Object#acts_like?.
        def acts_like_time?
          true
        end
      end
    end
  end
end
