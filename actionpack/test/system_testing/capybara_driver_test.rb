require 'abstract_unit'

class CapybaraDriverTest < ActiveSupport::TestCase
  def test_setting_useragent
    Rails::SystemTestCase.driver = SystemTesting::DriverAdapters::CapybaraDriver.new(
      :rack_test
    )
    assert_equal :rack_test, Rails::SystemTestCase.driver.name
  end
end
