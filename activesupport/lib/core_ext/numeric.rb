require File.dirname(__FILE__) + '/numeric/time'
require File.dirname(__FILE__) + '/numeric/bytes'

class Numeric #:nodoc:
  include ActiveSupport::CoreExtensions::Numeric::Time 
  include ActiveSupport::CoreExtensions::Numeric::Bytes 
end
