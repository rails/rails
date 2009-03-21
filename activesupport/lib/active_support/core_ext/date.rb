require 'active_support/core_ext/util'
require 'date'
require 'active_support/core_ext/date/acts_like'
require 'active_support/core_ext/date/freeze'
ActiveSupport.core_ext Date, %w(calculations conversions)
