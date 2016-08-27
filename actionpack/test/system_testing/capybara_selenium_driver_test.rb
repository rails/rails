require 'abstract_unit'

class CapybaraSeleniumDriverTest < ActiveSupport::TestCase
  def setup
    Rails::SystemTestCase.driver = :capybara_selenium_driver
  end

  def test_setting_driver_adapter_to_selenium
    assert_kind_of SystemTesting::DriverAdapters::CapybaraSeleniumDriver, Rails::SystemTestCase.driver
  end

  def test_default_settings
    assert_equal :chrome, Rails::SystemTestCase.driver.browser
    assert_equal :puma, Rails::SystemTestCase.driver.server
    assert_equal 28100, Rails::SystemTestCase.driver.port
    assert_equal [1400,1400], Rails::SystemTestCase.driver.screen_size
  end

  def test_setting_browser
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraSeleniumDriver.new(
      browser: :firefox
    )

    assert_equal :firefox, Rails::SystemTestCase.driver.browser
  end

  def test_setting_server
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraSeleniumDriver.new(
      server: :webrick
    )

    assert_equal :webrick, Rails::SystemTestCase.driver.server
  end

  def test_setting_port
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraSeleniumDriver.new(
      port: 3000
    )

    assert_equal 3000, Rails::SystemTestCase.driver.port
  end

  def test_setting_screen_size
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraSeleniumDriver.new(
      screen_size: [ 800, 800 ]
    )

    assert_equal [ 800, 800 ], Rails::SystemTestCase.driver.screen_size
  end

  def test_does_not_accept_nonsense_kwargs
    assert_raises ArgumentError do
      Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraSeleniumDriver.new(
        made_up_arg: 'x'
      )
    end
  end
end
