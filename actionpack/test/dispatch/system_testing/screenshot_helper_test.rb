require "abstract_unit"
require "action_dispatch/system_testing/test_helpers/screenshot_helper"
require "capybara/dsl"

class ScreenshotHelperTest < ActiveSupport::TestCase
  test "screenshots are not taken if disabled" do
    new_test = DrivenBySeleniumWithChrome.new("x")

    cached_env_value = ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"]
    ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"] = "disabled"

    assert new_test.send(:screenshots_disabled?)
    assert_nil new_test.take_failed_screenshot

    ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"] = cached_env_value
  end

  test "image path is saved in tmp directory" do
    new_test = DrivenBySeleniumWithChrome.new("x")

    assert_equal "tmp/screenshots/x.png", new_test.send(:image_path)
  end

  test "image path includes failures text if test did not pass" do
    new_test = DrivenBySeleniumWithChrome.new("x")

    new_test.stub :passed?, false do
      assert_equal "tmp/screenshots/failures_x.png", new_test.send(:image_path)
    end
  end

  test "image path does not include failures text if test skipped" do
    new_test = DrivenBySeleniumWithChrome.new("x")

    new_test.stub :passed?, false do
      new_test.stub :skipped?, true do
        assert_equal "tmp/screenshots/x.png", new_test.send(:image_path)
      end
    end
  end
end

class RackTestScreenshotsTest < DrivenByRackTest
  test "rack_test driver does not support screenshot" do
    assert_not self.send(:supports_screenshot?)
  end
end

class SeleniumScreenshotsTest < DrivenBySeleniumWithChrome
  test "selenium driver supports screenshot" do
    assert self.send(:supports_screenshot?)
  end
end
