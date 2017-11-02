# frozen_string_literal: true

require "monitor"

module ActiveSupport
  module Concurrency
    # A monitor that will permit dependency loading while blocked waiting for
    # the lock.
    class LoadInterlockAwareMonitor < Monitor
      # Enters an exclusive section, but allows dependency loading while blocked
      def mon_enter
        mon_try_enter ||
          ActiveSupport::Dependencies.interlock.permit_concurrent_loads { super }
      end
    end
  end
end
