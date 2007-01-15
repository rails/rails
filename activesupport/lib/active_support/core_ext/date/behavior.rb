module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Date #:nodoc:
      module Behavior
        # Enable more predictable duck-typing on Date-like classes. See
        # Object#acts_like?.
        def acts_like_date?
          true
        end
      end
    end
  end
end
