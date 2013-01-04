require 'active_support/core_ext/big_decimal/conversions'
require 'active_support/number_helper'
require 'active_support/core_ext/infinite_comparable'

class Float
  include InfiniteComparable
end

class BigDecimal
  include InfiniteComparable
end
