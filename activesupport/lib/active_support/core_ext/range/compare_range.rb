# frozen_string_literal: true

module ActiveSupport
  module CompareWithRange
    class << self
      def compare(range, other, &block) # :nodoc:
        return false if other_is_backwards?(other)

        begin_includes_other_begin?(range, other, &block) && end_includes_other_end?(range, other)
      end

      private
        def other_is_backwards?(other)
          is_backwards_op = other.exclude_end? ? :>= : :>
          other.begin && other.end && other.begin.public_send(is_backwards_op, other.end)
        end

        def begin_includes_other_begin?(range, other, &block)
          # A beginless range always includes the other range's begin.
          range.begin.nil? || block.call(other.begin)
        end

        def end_includes_other_end?(range, other)
          # An endless range always includes the other range's end.
          return true if range.end.nil?
          # If the other range is endless, it's not included.
          return false if other.end.nil?

          # 1...10 includes 1..9 but it does not include 1..10.
          # 1..10 includes 1...11 but it does not include 1...12.
          # We can't simplify to `max >= other.max` since it raises TypeError for exclusive ranges with float end points.
          range_exclude_end = range.exclude_end?
          other_exclude_end = other.exclude_end?
          operator = range_exclude_end && !other_exclude_end ? :< : :<=
          value_max = !range_exclude_end && other_exclude_end ? other.max : other.last
          value_max.public_send(operator, range.last)
        end
    end

    # Extends the default Range#=== to support range comparisons.
    #  (1..5) === (1..5)  # => true
    #  (1..5) === (2..3)  # => true
    #  (1..5) === (1...6) # => true
    #  (1..5) === (2..6)  # => false
    #
    # The native Range#=== behavior is untouched.
    #  ('a'..'f') === ('c') # => true
    #  (5..9) === (11) # => false
    def ===(other)
      if other.is_a?(::Range)
        CompareWithRange.compare(self, other) { |arg_for_comparison| super(arg_for_comparison) }
      else
        super
      end
    end

    # Extends the default Range#include? to support range comparisons.
    #  (1..5).include?(1..5)  # => true
    #  (1..5).include?(2..3)  # => true
    #  (1..5).include?(1...6) # => true
    #  (1..5).include?(2..6)  # => false
    #
    # The native Range#include? behavior is untouched.
    #  ('a'..'f').include?('c') # => true
    #  (5..9).include?(11) # => false
    def include?(other)
      if other.is_a?(::Range)
        CompareWithRange.compare(self, other) { |arg_for_comparison| super(arg_for_comparison) }
      else
        super
      end
    end
  end
end

Range.prepend(ActiveSupport::CompareWithRange)
