module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Date #:nodoc:
      module Behavior
        # Enable more predictable duck-typing on Date-like classes. See
        # Object#acts_like?.
        def acts_like_date?
          true
        end

        # Date memoizes some instance methods using metaprogramming to wrap
        # the methods with one that caches the result in an instance variable.
        # If a Date is frozen but the memoized method hasn't been called, the
        # first call will result in a frozen object error since the memo
        # instance variable is uninitialized.
        #
        # Work around by eagerly memoizing before freezing.
        #
        # Ruby 1.9 uses a preinitialized instance variable so it's unaffected.
        # This hack is as close as we can get to feature detection:
        begin
          ::Date.today.freeze.jd
        rescue => frozen_object_error
          if frozen_object_error.message =~ /frozen/
            def freeze #:nodoc:
              self.class.private_instance_methods(false).each do |m|
                if m.to_s =~ /\A__\d+__\Z/
                  instance_variable_set(:"@#{m}", [send(m)])
                end
              end

              super
            end
          end
        end
      end
    end
  end
end
