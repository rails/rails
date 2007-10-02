require 'active_support/core_ext/numeric/time'
require 'active_support/core_ext/numeric/bytes'

class Numeric #:nodoc:
  include ActiveSupport::CoreExtensions::Numeric::Time 
  include ActiveSupport::CoreExtensions::Numeric::Bytes 
end
