require 'system_testing/test_helper'
require 'system_testing/driver_adapter'

module SystemTesting
  module Base
    include TestHelper
    include DriverAdapter
  end
end
