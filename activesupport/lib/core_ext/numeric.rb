$:.unshift(File.dirname(__FILE__))
require 'numeric/time'
require 'numeric/bytes'

class Numeric
  include ActiveSupport::CoreExtensions::Numeric::Time 
  include ActiveSupport::CoreExtensions::Numeric::Bytes 
end
