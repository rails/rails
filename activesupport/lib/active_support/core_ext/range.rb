require 'active_support/core_ext/range/conversions'
require File.dirname(__FILE__) + '/range/overlaps'
require File.dirname(__FILE__) + '/range/include_range'
require File.dirname(__FILE__) + '/range/blockless_step'

class Range #:nodoc:
  include ActiveSupport::CoreExtensions::Range::Conversions
  include ActiveSupport::CoreExtensions::Range::Overlaps
  include ActiveSupport::CoreExtensions::Range::IncludeRange
  include ActiveSupport::CoreExtensions::Range::BlocklessStep
end
