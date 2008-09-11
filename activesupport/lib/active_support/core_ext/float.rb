require 'active_support/core_ext/float/rounding'
require 'active_support/core_ext/float/time'

class Float #:nodoc:
  include ActiveSupport::CoreExtensions::Float::Rounding
  include ActiveSupport::CoreExtensions::Float::Time
end
