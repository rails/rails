require 'abstract_unit'

class RailsSeleniumDriverTest < ActiveSupport::TestCase
  def setup
    Rails::SystemTestCase.driver = :rails_selenium_driver
  end

  def test_default_driver_adapter
    assert_kind_of SystemTesting::DriverAdapters::RailsSeleniumDriver, Rails::SystemTestCase.driver
  end

  def test_default_settings
    assert_equal :chrome, Rails::SystemTestCase.driver.browser
    assert_equal :puma, Rails::SystemTestCase.driver.server
    assert_equal 28100, Rails::SystemTestCase.driver.port
    assert_equal [1400,1400], Rails::SystemTestCase.driver.screen_size
  end

  def test_setting_browser
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::RailsSeleniumDriver.new(
      browser: :firefox
    )

    assert_equal :firefox, Rails::SystemTestCase.driver.browser
  end

  def test_setting_server
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::RailsSeleniumDriver.new(
      server: :webrick
    )

    assert_equal :webrick, Rails::SystemTestCase.driver.server
  end

  def test_setting_port
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::RailsSeleniumDriver.new(
      port: 3000
    )

    assert_equal 3000, Rails::SystemTestCase.driver.port
  end

  def test_setting_screen_size
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::RailsSeleniumDriver.new(
      screen_size: [ 800, 800 ]
    )

    assert_equal [ 800, 800 ], Rails::SystemTestCase.driver.screen_size
  end

  def test_does_not_accept_nonsense_kwargs
    assert_raises ArgumentError do
      Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::RailsSeleniumDriver.new(
        made_up_arg: 'x'
      )
    end
  end
end
