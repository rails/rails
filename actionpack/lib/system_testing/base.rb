require 'system_testing/test_helper'
require 'system_testing/driver_adapter'

module SystemTesting
  module Base
    include TestHelper
    include DriverAdapter

    ActiveSupport.run_load_hooks(:system_testing, self)
  end
end
