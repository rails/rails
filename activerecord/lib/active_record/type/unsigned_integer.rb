module ActiveRecord
  module Type
    class UnsignedInteger < ActiveModel::Type::Integer # :nodoc:
      private

        # The maximum value for an unsigned integer.
        # It is twice as much as a signed integer because it does not have to
        # account for negative values in the memory space.
        def max_value
          super * 2
        end

        # The minimum value for an unsigned integer.
        # Because unsigned integers are only nonnegative, the minimum value is
        # always zero.
        def min_value
          0
        end
    end
  end
end
