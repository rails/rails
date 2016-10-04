require "abstract_unit"

class ScreenshotHelperTest < ActiveSupport::TestCase
  def test_driver_support_for_screenshots
    Rails::SystemTestCase.driver = :rails_selenium_driver
    assert Rails::SystemTestCase.driver.supports_screenshots?

    Rails::SystemTestCase.driver = :rack_test
    assert_not Rails::SystemTestCase.driver.supports_screenshots?

    Rails::SystemTestCase.driver = :selenium
    assert Rails::SystemTestCase.driver.supports_screenshots?

    Rails::SystemTestCase.driver = :webkit
    assert Rails::SystemTestCase.driver.supports_screenshots?

    Rails::SystemTestCase.driver = :poltergeist
    assert Rails::SystemTestCase.driver.supports_screenshots?
  end
end
