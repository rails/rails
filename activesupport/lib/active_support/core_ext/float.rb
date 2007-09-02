require File.dirname(__FILE__) + '/float/rounding'

class Float #:nodoc:
  include ActiveSupport::CoreExtensions::Float::Rounding
end
