require 'active_support/deprecation/behaviors'
require 'active_support/deprecation/reporting'
require 'active_support/deprecation/method_wrappers'
require 'active_support/deprecation/proxy_wrappers'

module ActiveSupport
  module Deprecation
    class << self
      # The version the deprecated behavior will be removed, by default.
      attr_accessor :deprecation_horizon
    end
    self.deprecation_horizon = '4.0'

    # By default, warnings are not silenced and debugging is off.
    self.silenced = false
    self.debug = false
  end
end