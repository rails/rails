module ActiveSupport
  module IncludeWithRange #:nodoc:
    # Extends the default Range#include? to support range comparisons.
    #  (1..5).include?(1..5) # => true
    #  (1..5).include?(2..3) # => true
    #  (1..5).include?(2..6) # => false
    #
    # The native Range#include? behavior is untouched.
    #  ('a'..'f').include?('c') # => true
    #  (5..9).include?(11) # => false
    def include?(value)
      if value.is_a?(::Range)
        # 1...10 includes 1..9 but it does not include 1..10.
        operator = exclude_end? && !value.exclude_end? ? :< : :<=
        super(value.first) && value.last.send(operator, last)
      else
        super
      end
    end
  end
end

Range.prepend(ActiveSupport::IncludeWithRange)
