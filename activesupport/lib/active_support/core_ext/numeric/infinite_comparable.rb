require 'active_support/core_ext/big_decimal/conversions'
require 'active_support/number_helper'

class Numeric
  [Float, BigDecimal].each do |klass|

    origin_compare = klass.send(:instance_method, :<=>)

    klass.send(:define_method , :<=>) do |other|
      return origin_compare.bind(self).call(other) if other.class == self.class

      return 0 if infinite? && other.respond_to?(:infinite?) && infinite? == other.infinite?

      infinite? || origin_compare.bind(self).call(other)
    end
  end
end
