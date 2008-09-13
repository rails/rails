module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      module Behavior
        # Enable more predictable duck-typing on String-like classes. See
        # Object#acts_like?.
        def acts_like_string?
          true
        end
      end
    end
  end
end