require "active_support/testing/autorun"
require "action_system_test"

class DriverTest < ActiveSupport::TestCase
  test "initializing the driver" do
    driver = ActionSystemTest::Driver.new(:selenium)
    assert_equal :selenium, driver.instance_variable_get(:@name)
  end
end
