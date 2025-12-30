# frozen_string_literal: true

require "monitor"

module ActiveSupport
  module Concurrency
    # A monitor that will permit dependency loading while blocked waiting for
    # the lock.
    LoadInterlockAwareMonitor = ActiveSupport::Deprecation::DeprecatedConstantProxy.new(
      "ActiveSupport::Concurrency::LoadInterlockAwareMonitor",
      "::Monitor",
      ActiveSupport.deprecator,
      message: "ActiveSupport::Concurrency::LoadInterlockAwareMonitor is deprecated and will be " \
               "removed in Rails 9.0. Use Monitor directly instead, as the loading interlock is " \
               "no longer used."
    )
  end
end
