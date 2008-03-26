require 'bigdecimal'
require 'active_support/core_ext/bigdecimal/conversions'

class BigDecimal#:nodoc:
  include ActiveSupport::CoreExtensions::BigDecimal::Conversions
end
