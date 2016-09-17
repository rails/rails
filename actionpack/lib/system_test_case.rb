require 'system_testing/test_helper'
require 'system_testing/driver_adapter'

module Rails
  class SystemTestCase < ActionDispatch::IntegrationTest
    include SystemTesting::TestHelper
    include SystemTesting::DriverAdapter

    ActiveSupport.run_load_hooks(:system_testing, self)
  end
end
