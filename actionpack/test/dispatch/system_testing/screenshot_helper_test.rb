# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/system_testing/test_helpers/screenshot_helper"
require "capybara/dsl"

class ScreenshotHelperTest < ActiveSupport::TestCase
  %w(image html).each do |format|
    ext = format == "image" ? "png" : "html"

    test "#{format} path is saved in tmp directory" do
      new_test = DrivenBySeleniumWithChrome.new("x")

      Rails.stub :root, Pathname.getwd do
        assert_equal Rails.root.join("tmp/screenshots/x.#{ext}").to_s, new_test.send(:"#{format}_path")
      end
    end

    test "#{format} path includes failures text if test did not pass" do
      new_test = DrivenBySeleniumWithChrome.new("x")

      Rails.stub :root, Pathname.getwd do
        new_test.stub :passed?, false do
          assert_equal Rails.root.join("tmp/screenshots/failures_x.#{ext}").to_s, new_test.send(:"#{format}_path")
        end
      end
    end

    test "#{format} path does not include failures text if test skipped" do
      new_test = DrivenBySeleniumWithChrome.new("x")

      Rails.stub :root, Pathname.getwd do
        new_test.stub :passed?, false do
          new_test.stub :skipped?, true do
            assert_equal Rails.root.join("tmp/screenshots/x.#{ext}").to_s, new_test.send(:"#{format}_path")
          end
        end
      end
    end

    test "#{format} path returns the absolute path from root" do
      new_test = DrivenBySeleniumWithChrome.new("x")

      Rails.stub :root, Pathname.getwd.join("..") do
        assert_equal Rails.root.join("tmp/screenshots/x.#{ext}").to_s, new_test.send(:"#{format}_path")
      end
    end
  end

  test "defaults to simple output for the screenshot" do
    new_test = DrivenBySeleniumWithChrome.new("x")
    assert_equal "simple", new_test.send(:output_type)
  end

  test "display_screenshot includes artifact protocol when RAILS_SYSTEM_TESTING_SCREENSHOT environment specified" do
    begin
      original_output_type = ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"]
      ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"] = "artifact"

      new_test = DrivenBySeleniumWithChrome.new("x")

      assert_equal "artifact", new_test.send(:output_type)

      Rails.stub :root, Pathname.getwd do
        assert_match %r|url=artifact://.+?tmp/screenshots/x\.png|, new_test.send(:display_screenshot)
      end
    ensure
      ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"] = original_output_type
    end
  end

  test "display_screenshot includes file protocol easily opening links" do
    new_test = DrivenBySeleniumWithChrome.new("x")

    Rails.stub :root, Pathname.getwd do
      assert_match %r|file://.+?tmp/screenshots/x\.png|, new_test.send(:display_screenshot)
      assert_match %r|file://.+?tmp/screenshots/x\.html|, new_test.send(:display_screenshot)
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
