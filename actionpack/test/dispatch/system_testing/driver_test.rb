# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/system_testing/driver"

class DriverTest < ActiveSupport::TestCase
  test "initializing the driver" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium)
    assert_equal :selenium, driver.instance_variable_get(:@name)
  end

  test "initializing the driver with a browser" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, using: :chrome, screen_size: [1400, 1400], options: { url: "http://example.com/wd/hub" })
    assert_equal :selenium, driver.instance_variable_get(:@name)
    assert_equal :chrome, driver.instance_variable_get(:@browser).name
    assert_nil driver.instance_variable_get(:@browser).options
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ url: "http://example.com/wd/hub" }), driver.instance_variable_get(:@options)
  end

  test "initializing the driver with a headless chrome" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, using: :headless_chrome, screen_size: [1400, 1400], options: { url: "http://example.com/wd/hub" })
    assert_equal :selenium, driver.instance_variable_get(:@name)
    assert_equal :headless_chrome, driver.instance_variable_get(:@browser).name
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ url: "http://example.com/wd/hub" }), driver.instance_variable_get(:@options)
  end

  test "initializing the driver with a headless firefox" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, using: :headless_firefox, screen_size: [1400, 1400], options: { url: "http://example.com/wd/hub" })
    assert_equal :selenium, driver.instance_variable_get(:@name)
    assert_equal :headless_firefox, driver.instance_variable_get(:@browser).name
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ url: "http://example.com/wd/hub" }), driver.instance_variable_get(:@options)
  end

  test "initializing the driver with a poltergeist" do
    driver = ActionDispatch::SystemTesting::Driver.new(:poltergeist, screen_size: [1400, 1400], options: { js_errors: false })
    assert_equal :poltergeist, driver.instance_variable_get(:@name)
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ js_errors: false }), driver.instance_variable_get(:@options)
  end

  test "initializing the driver with a webkit" do
    driver = ActionDispatch::SystemTesting::Driver.new(:webkit, screen_size: [1400, 1400], options: { skip_image_loading: true })
    assert_equal :webkit, driver.instance_variable_get(:@name)
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ skip_image_loading: true }), driver.instance_variable_get(:@options)
  end

  test "registerable? returns false if driver is rack_test" do
    assert_not ActionDispatch::SystemTesting::Driver.new(:rack_test).send(:registerable?)
  end
end
