require 'active_support/core_ext/infinite_comparable'

class Float
  include InfiniteComparable
end

class BigDecimal
  include InfiniteComparable
end
