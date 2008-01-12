require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/numeric/bytes'
require 'active_support/core_ext/numeric/conversions'

class Numeric #:nodoc:
  include ActiveSupport::CoreExtensions::Numeric::Time 
  include ActiveSupport::CoreExtensions::Numeric::Bytes
  include ActiveSupport::CoreExtensions::Numeric::Conversions 
end
