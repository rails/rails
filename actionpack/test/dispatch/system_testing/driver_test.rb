# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/system_testing/driver"
require "selenium/webdriver"

class DriverTest < ActiveSupport::TestCase
  test "initializing the driver" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium)
    assert_equal :selenium, driver.instance_variable_get(:@driver_type)
  end

  test "initializing the driver with a browser" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, using: :chrome, screen_size: [1400, 1400], options: { url: "http://example.com/wd/hub" })
    assert_equal :selenium, driver.instance_variable_get(:@driver_type)
    assert_equal :chrome, driver.instance_variable_get(:@browser).name
    assert_instance_of Selenium::WebDriver::Chrome::Options, driver.instance_variable_get(:@browser).options
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ url: "http://example.com/wd/hub" }), driver.instance_variable_get(:@options)
  end

  test "initializing the driver with a headless chrome" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, using: :headless_chrome, screen_size: [1400, 1400], options: { url: "http://example.com/wd/hub" })
    assert_equal :selenium, driver.instance_variable_get(:@driver_type)
    assert_equal :headless_chrome, driver.instance_variable_get(:@browser).name
    assert_instance_of Selenium::WebDriver::Chrome::Options, driver.instance_variable_get(:@browser).options
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ url: "http://example.com/wd/hub" }), driver.instance_variable_get(:@options)
  end

  test "initializing the driver with a headless chrome and custom path" do
    original_driver_path = ::Selenium::WebDriver::Chrome::Service.driver_path
    assert_nothing_raised do
      ::Selenium::WebDriver::Chrome::Service.driver_path = "bin/test"
      ActionDispatch::SystemTesting::Driver.new(:selenium, using: :headless_chrome, screen_size: [1400, 1400])
    end
  ensure
    ::Selenium::WebDriver::Chrome::Service.driver_path = original_driver_path
  end

  test "initializing the driver with a headless firefox" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, using: :headless_firefox, screen_size: [1400, 1400], options: { url: "http://example.com/wd/hub" })
    assert_equal :selenium, driver.instance_variable_get(:@driver_type)
    assert_equal :headless_firefox, driver.instance_variable_get(:@browser).name
    assert_instance_of Selenium::WebDriver::Firefox::Options, driver.instance_variable_get(:@browser).options
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ url: "http://example.com/wd/hub" }), driver.instance_variable_get(:@options)
  end

  test "initializing the driver with a headless firefox and custom path" do
    original_driver_path = ::Selenium::WebDriver::Firefox::Service.driver_path
    assert_nothing_raised do
      ::Selenium::WebDriver::Firefox::Service.driver_path = "bin/test"
      ActionDispatch::SystemTesting::Driver.new(:selenium, using: :headless_firefox, screen_size: [1400, 1400])
    end
  ensure
    ::Selenium::WebDriver::Firefox::Service.driver_path = original_driver_path
  end

  test "initializing the driver with a cuprite" do
    driver = ActionDispatch::SystemTesting::Driver.new(:cuprite, screen_size: [1400, 1400], options: { js_errors: false })
    assert_equal :cuprite, driver.instance_variable_get(:@driver_type)
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ js_errors: false }), driver.instance_variable_get(:@options)
  end

  test "initializing the driver with Playwright" do
    driver = ActionDispatch::SystemTesting::Driver.new(:playwright, screen_size: [1400, 1400], options: { headless: true })

    assert_equal :playwright, driver.instance_variable_get(:@driver_type)
    assert_equal [1400, 1400], driver.instance_variable_get(:@screen_size)
    assert_equal ({ headless: true }), driver.instance_variable_get(:@options)
  end

  test "define extra capabilities using chrome" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, screen_size: [1400, 1400], using: :chrome) do |option|
      option.add_argument("start-maximized")
      option.add_emulation(device_name: "iphone 6")
      option.add_preference(:detach, true)
    end
    driver.use

    expected = {
      "goog:chromeOptions" => {
        "args" => ["--disable-search-engine-choice-screen", "start-maximized"],
        "mobileEmulation" => { "deviceName" => "iphone 6" },
        "prefs" => { "detach" => true }
      },
      "browserName" => "chrome"
    }
    assert_driver_capabilities driver, expected
  end

  test "define extra capabilities using headless_chrome" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, screen_size: [1400, 1400], using: :headless_chrome) do |option|
      option.add_argument("start-maximized")
      option.add_emulation(device_name: "iphone 6")
      option.add_preference(:detach, true)
    end
    driver.use

    expected = {
      "goog:chromeOptions" => {
        "args" => ["--disable-search-engine-choice-screen", "--headless", "start-maximized"],
        "mobileEmulation" => { "deviceName" => "iphone 6" },
        "prefs" => { "detach" => true }
      },
      "browserName" => "chrome"
    }
    assert_driver_capabilities driver, expected
  end

  test "define extra capabilities using firefox" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, screen_size: [1400, 1400], using: :firefox) do |option|
      option.add_preference("browser.startup.homepage", "http://www.seleniumhq.com/")
      option.add_argument("--host=127.0.0.1")
    end
    driver.use

    expected = {
      "moz:firefoxOptions" => {
        "args" => ["--host=127.0.0.1"],
        "prefs" => { "remote.active-protocols" => 3, "browser.startup.homepage" => "http://www.seleniumhq.com/" }
      },
      "browserName" => "firefox"
    }
    assert_driver_capabilities driver, expected
  end

  test "define extra capabilities using headless_firefox" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, screen_size: [1400, 1400], using: :headless_firefox) do |option|
      option.add_preference("browser.startup.homepage", "http://www.seleniumhq.com/")
      option.add_argument("--host=127.0.0.1")
    end
    driver.use

    expected = {
      "moz:firefoxOptions" => {
        "args" => ["-headless", "--host=127.0.0.1"],
        "prefs" => { "remote.active-protocols" => 3, "browser.startup.homepage" => "http://www.seleniumhq.com/" }
      },
      "browserName" => "firefox"
    }
    assert_driver_capabilities driver, expected
  end

  test "does not define extra capabilities" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, screen_size: [1400, 1400], using: :firefox)

    assert_nothing_raised do
      driver.use
    end
  end

  test "preloads browser's driver_path with DriverFinder if a path isn't already specified" do
    original_driver_path = ::Selenium::WebDriver::Chrome::Service.driver_path
    ::Selenium::WebDriver::Chrome::Service.driver_path = nil

    # Our stub must return paths to a real executables, otherwise an internal Selenium assertion will fail.
    # Note: SeleniumManager is private api
    found_executable = RbConfig.ruby
    ::Selenium::WebDriver::SeleniumManager.stub(:binary_paths, { "driver_path" => found_executable, "browser_path" => found_executable }) do
      ActionDispatch::SystemTesting::Driver.new(:selenium, screen_size: [1400, 1400], using: :chrome)
    end

    assert_equal found_executable, ::Selenium::WebDriver::Chrome::Service.driver_path
  ensure
    ::Selenium::WebDriver::Chrome::Service.driver_path = original_driver_path
  end

  test "does not overwrite existing driver_path during preload" do
    original_driver_path = ::Selenium::WebDriver::Chrome::Service.driver_path
    # The driver_path must point to a real executable, otherwise an internal Selenium assertion will fail.
    ::Selenium::WebDriver::Chrome::Service.driver_path = RbConfig.ruby

    assert_no_changes -> { ::Selenium::WebDriver::Chrome::Service.driver_path } do
      ActionDispatch::SystemTesting::Driver.new(:selenium, screen_size: [1400, 1400], using: :chrome)
    end
  ensure
    ::Selenium::WebDriver::Chrome::Service.driver_path = original_driver_path
  end

  test "does not configure browser if driver is not :selenium" do
    # Check that it does configure browser if the driver is :selenium
    assert ActionDispatch::SystemTesting::Driver.new(:selenium).instance_variable_get(:@browser)

    assert_nil ActionDispatch::SystemTesting::Driver.new(:rack_test).instance_variable_get(:@browser)
    assert_nil ActionDispatch::SystemTesting::Driver.new(:cuprite).instance_variable_get(:@browser)
  end

  test "driver names default to driver type" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium)
    assert_equal :selenium, driver.name
  end

  test "driver names can by specified explicitly" do
    driver = ActionDispatch::SystemTesting::Driver.new(:selenium, options: { name: :best_driver })
    assert_equal :best_driver, driver.name
  end

  private
    def assert_driver_capabilities(driver, expected_capabilities)
      capabilities = driver.__send__(:browser_options)[:options].as_json

      assert_equal expected_capabilities, capabilities.slice(*expected_capabilities.keys)
    end
end
