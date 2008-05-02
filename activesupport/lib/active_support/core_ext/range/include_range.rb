module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Range #:nodoc:
      # Check if a Range includes another Range.
      module IncludeRange
        def self.included(base) #:nodoc:
          base.alias_method_chain :include?, :range
        end

        # Extends the default Range#include? to support range comparisons.
        #  (1..5).include?(1..5) # => true
        #  (1..5).include?(2..3) # => true
        #  (1..5).include?(2..6) # => false
        #
        # The native Range#include? behavior is untouched.
        #  ("a".."f").include?("c") # => true
        #  (5..9).include?(11) # => false
        def include_with_range?(value)
          if value.is_a?(::Range)
            operator = exclude_end? ? :< : :<=
            end_value = value.exclude_end? ? last.succ : last
            include?(value.first) && (value.last <=> end_value).send(operator, 0)
          else
            include_without_range?(value)
          end
        end
      end
    end
  end
end
