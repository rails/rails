require "abstract_unit"

class RailsSeleniumDriverTest < ActiveSupport::TestCase
  def setup
    ActionSystemTest.driver = :rails_selenium_driver
  end

  def test_default_driver_adapter
    assert_kind_of ActionSystemTest::DriverAdapters::RailsSeleniumDriver, ActionSystemTest.driver
  end
end
