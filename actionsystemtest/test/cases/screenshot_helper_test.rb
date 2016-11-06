require "abstract_unit"

class ScreenshotHelperTest < ActiveSupport::TestCase
  def test_driver_support_for_screenshots
    ActionSystemTest.driver = :rails_selenium_driver
    assert ActionSystemTest.driver.supports_screenshots?

    ActionSystemTest.driver = :rack_test
    assert_not ActionSystemTest.driver.supports_screenshots?

    ActionSystemTest.driver = :selenium
    assert ActionSystemTest.driver.supports_screenshots?

    ActionSystemTest.driver = :webkit
    assert ActionSystemTest.driver.supports_screenshots?

    ActionSystemTest.driver = :poltergeist
    assert ActionSystemTest.driver.supports_screenshots?
  end
end
