require 'abstract_unit'

class CapybaraRackTestDriverTest < ActiveSupport::TestCase
  def test_default_driver_adapter
    assert_kind_of SystemTesting::DriverAdapters::CapybaraRackTestDriver, Rails::SystemTestCase.driver
  end

  def test_default_settings
    assert_equal 'Capybara', Rails::SystemTestCase.driver.useragent
  end

  def test_setting_useragent
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraRackTestDriver.new(
      useragent: 'x'
    )
    assert_equal 'x', Rails::SystemTestCase.driver.useragent
  end

  def test_does_not_accept_nonsense_kwargs
    assert_raises ArgumentError do
      Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraRackTestDriver.new(
        made_up_arg: 'x'
      )
    end
  end
end
