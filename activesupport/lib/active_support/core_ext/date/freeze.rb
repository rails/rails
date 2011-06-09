# Date memoizes some instance methods using metaprogramming to wrap
# the methods with one that caches the result in an instance variable.
#
# If a Date is frozen but the memoized method hasn't been called, the
# first call will result in a frozen object error since the memo
# instance variable is uninitialized.
#
# Work around by eagerly memoizing before the first freeze.
#
# Ruby 1.9 uses a preinitialized instance variable so it's unaffected.
# This hack is as close as we can get to feature detection:
if RUBY_VERSION < '1.9'
  require 'date'
  begin
    ::Date.today.freeze.jd
  rescue => frozen_object_error
    if frozen_object_error.message =~ /frozen/
      class Date #:nodoc:
        def freeze
          unless frozen?
            self.class.private_instance_methods(false).each do |m|
              if m.to_s =~ /\A__\d+__\Z/
                instance_variable_set(:"@#{m}", [send(m)])
              end
            end
          end

          super
        end
      end
    end
  end
end
