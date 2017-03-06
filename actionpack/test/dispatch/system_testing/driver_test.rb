require "abstract_unit"
require "action_dispatch/system_testing/driver"

class DriverTest < ActiveSupport::TestCase
  test "initializing the driver" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium)
    assert_equal :selenium, driver.instance_variable_get(:@name)
  end

  test "initializing the driver with a browser" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, using: :chrome, screen_size: [1400, 1400])
    assert_equal :selenium, driver.instance_variable_get(:@name)
    assert_equal :chrome, driver.instance_variable_get(:@browser)
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
  end

  test "selenium? returns false if driver is poltergeist" do
    assert_not ActionDispatch::SystemTesting::Driver.new(:poltergeist).send(:selenium?)
  end
end
