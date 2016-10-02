require 'abstract_unit'

class CapybaraDriverTest < ActiveSupport::TestCase
  def setup
    Rails::SystemTestCase.driver = :poltergeist
  end

  def test_default_driver_adapter
    assert_kind_of SystemTesting::DriverAdapters::CapybaraDriver, Rails::SystemTestCase.driver
  end

  def test_default_settings
    assert_equal :poltergeist, Rails::SystemTestCase.driver.name
    assert_equal :puma, Rails::SystemTestCase.driver.server
    assert_equal 28100, Rails::SystemTestCase.driver.port
  end

  def test_setting_driver
    Rails::SystemTestCase.driver = :webkit

    assert_equal :webkit, Rails::SystemTestCase.driver.name
  end

  def test_setting_server
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraDriver.new(
      server: :webrick
    )

    assert_equal :webrick, Rails::SystemTestCase.driver.server
  end

  def test_setting_port
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraDriver.new(
      port: 3000
    )

    assert_equal 3000, Rails::SystemTestCase.driver.port
  end
end
