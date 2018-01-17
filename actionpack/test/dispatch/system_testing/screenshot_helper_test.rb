# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/system_testing/test_helpers/screenshot_helper"
require "capybara/dsl"

class ScreenshotHelperTest < ActiveSupport::TestCase
  test "image path is saved in tmp directory" do
    new_test = DrivenBySeleniumWithChrome.new("x")

    Rails.stub :root, Pathname.getwd do
      assert_equal "tmp/screenshots/x.png", new_test.send(:image_path)
    end
  end

  test "image path includes failures text if test did not pass" do
    new_test = DrivenBySeleniumWithChrome.new("x")

    Rails.stub :root, Pathname.getwd do
      new_test.stub :passed?, false do
        assert_equal "tmp/screenshots/failures_x.png", new_test.send(:image_path)
      end
    end
  end

  test "image path does not include failures text if test skipped" do
    new_test = DrivenBySeleniumWithChrome.new("x")

    Rails.stub :root, Pathname.getwd do
      new_test.stub :passed?, false do
        new_test.stub :skipped?, true do
          assert_equal "tmp/screenshots/x.png", new_test.send(:image_path)
        end
      end
    end
  end

  test "defaults to simple output for the screenshot" do
    new_test = DrivenBySeleniumWithChrome.new("x")
    assert_equal "simple", new_test.send(:output_type)
  end

  test "display_image return artifact format when specify RAILS_SYSTEM_TESTING_SCREENSHOT environment" do
    begin
      original_output_type = ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"]
      ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"] = "artifact"

      new_test = DrivenBySeleniumWithChrome.new("x")

      assert_equal "artifact", new_test.send(:output_type)

      Rails.stub :root, Pathname.getwd do
        new_test.stub :passed?, false do
          assert_match %r|url=artifact://.+?tmp/screenshots/failures_x\.png|, new_test.send(:display_image)
        end
      end
    ensure
      ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"] = original_output_type
    end
  end

  test "image path returns the relative path from current directory" do
    new_test = DrivenBySeleniumWithChrome.new("x")

    Rails.stub :root, Pathname.getwd.join("..") do
      assert_equal "../tmp/screenshots/x.png", new_test.send(:image_path)
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
