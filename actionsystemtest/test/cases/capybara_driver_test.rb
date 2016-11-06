require "abstract_unit"

class CapybaraDriverTest < ActiveSupport::TestCase
  def setup
    ActionSystemTest.driver = :poltergeist
  end

  def test_default_driver_adapter
    assert_kind_of ActionSystemTest::DriverAdapters::CapybaraDriver, ActionSystemTest.driver
  end

  def test_default_settings
    assert_equal :poltergeist, ActionSystemTest.driver.name
    assert_equal :puma, ActionSystemTest.driver.server
    assert_equal 28100, ActionSystemTest.driver.port
  end

  def test_setting_driver
    ActionSystemTest.driver = :webkit

    assert_equal :webkit, ActionSystemTest.driver.name
  end

  def test_setting_server
    ActionSystemTest.driver = ActionSystemTest::DriverAdapters::CapybaraDriver.new(
      server: :webrick
    )

    assert_equal :webrick, ActionSystemTest.driver.server
  end

  def test_setting_port
    ActionSystemTest.driver = ActionSystemTest::DriverAdapters::CapybaraDriver.new(
      port: 3000
    )

    assert_equal 3000, ActionSystemTest.driver.port
  end
end
