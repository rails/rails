require 'active_support/core_ext/range/conversions'
require 'active_support/core_ext/range/overlaps'
require 'active_support/core_ext/range/include_range'
require 'active_support/core_ext/range/blockless_step'

class Range #:nodoc:
  include ActiveSupport::CoreExtensions::Range::Conversions
  include ActiveSupport::CoreExtensions::Range::Overlaps
  include ActiveSupport::CoreExtensions::Range::IncludeRange
  include ActiveSupport::CoreExtensions::Range::BlocklessStep
end
