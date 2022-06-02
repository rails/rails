# frozen_string_literal: true

require "abstract_unit"
require "action_dispatch/system_testing/test_helpers/screenshot_helper"
require "capybara/dsl"
require "selenium/webdriver"

class ScreenshotHelperTest < ActiveSupport::TestCase
  def setup
    @new_test = DrivenBySeleniumWithChrome.new("x")
    @new_test.send("_screenshot_counter=", nil)
  end

  test "image path is saved in tmp directory" do
    Rails.stub :root, Pathname.getwd do
      assert_equal Rails.root.join("tmp/screenshots/0_x.png").to_s, @new_test.send(:image_path)
    end
  end

  test "image path unique counter is changed when incremented" do
    @new_test.send(:increment_unique)

    Rails.stub :root, Pathname.getwd do
      assert_equal Rails.root.join("tmp/screenshots/1_x.png").to_s, @new_test.send(:image_path)
    end
  end

  # To allow multiple screenshots in same test
  test "image path unique counter generates different path in same test" do
    Rails.stub :root, Pathname.getwd do
      @new_test.send(:increment_unique)
      assert_equal Rails.root.join("tmp/screenshots/1_x.png").to_s, @new_test.send(:image_path)

      @new_test.send(:increment_unique)
      assert_equal Rails.root.join("tmp/screenshots/2_x.png").to_s, @new_test.send(:image_path)
    end
  end

  test "image path uses the Capybara.save_path to set a custom directory" do
    original_save_path = Capybara.save_path
    Capybara.save_path = "custom_dir"

    Rails.stub :root, Pathname.getwd do
      assert_equal Rails.root.join("custom_dir/0_x.png").to_s, @new_test.send(:image_path)
    end
  ensure
    Capybara.save_path = original_save_path
  end

  test "image path includes failures text if test did not pass" do
    Rails.stub :root, Pathname.getwd do
      @new_test.stub :passed?, false do
        assert_equal Rails.root.join("tmp/screenshots/failures_x.png").to_s, @new_test.send(:image_path)
        assert_equal Rails.root.join("tmp/screenshots/failures_x.html").to_s, @new_test.send(:html_path)
      end
    end
  end

  test "image path does not include failures text if test skipped" do
    Rails.stub :root, Pathname.getwd do
      @new_test.stub :passed?, false do
        @new_test.stub :skipped?, true do
          assert_equal Rails.root.join("tmp/screenshots/0_x.png").to_s, @new_test.send(:image_path)
          assert_equal Rails.root.join("tmp/screenshots/0_x.html").to_s, @new_test.send(:html_path)
        end
      end
    end
  end

  test "image name truncates names over 225 characters including counter" do
    long_test = DrivenBySeleniumWithChrome.new("x" * 400)

    Rails.stub :root, Pathname.getwd do
      assert_equal Rails.root.join("tmp/screenshots/0_#{"x" * 223}.png").to_s, long_test.send(:image_path)
      assert_equal Rails.root.join("tmp/screenshots/0_#{"x" * 223}.html").to_s, long_test.send(:html_path)
    end
  end

  test "defaults to simple output for the screenshot" do
    assert_equal "simple", @new_test.send(:output_type)
  end

  test "take_screenshot saves HTML and shows link to it when using RAILS_SYSTEM_TESTING_SCREENSHOT_HTML env" do
    original_html_setting = ENV["RAILS_SYSTEM_TESTING_SCREENSHOT_HTML"]
    ENV["RAILS_SYSTEM_TESTING_SCREENSHOT_HTML"] = "1"

    display_image_actual = nil
    called_save_html = false

    Rails.stub :root, Pathname.getwd do
      @new_test.stub :save_image, nil do
        @new_test.stub :show, -> (img) { display_image_actual = img } do
          @new_test.stub :save_html, -> { called_save_html = true } do
            @new_test.take_screenshot
          end
        end
      end
    end
    assert called_save_html
    assert_match %r|\[Screenshot HTML\].+?tmp/screenshots/1_x\.html|, display_image_actual
  ensure
    ENV["RAILS_SYSTEM_TESTING_SCREENSHOT_HTML"] = original_html_setting
  end

  test "take_screenshot saves HTML and shows link to it when using html: kwarg" do
    display_image_actual = nil
    called_save_html = false

    Rails.stub :root, Pathname.getwd do
      @new_test.stub :save_image, nil do
        @new_test.stub :show, -> (img) { display_image_actual = img } do
          @new_test.stub :save_html, -> { called_save_html = true } do
            @new_test.take_screenshot(html: true)
          end
        end
      end
    end
    assert called_save_html
    assert_match %r|\[Screenshot HTML\].+?tmp/screenshots/1_x\.html|, display_image_actual
  end

  test "take_screenshot allows changing screeenshot display format via RAILS_SYSTEM_TESTING_SCREENSHOT env" do
    original_output_type = ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"]
    ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"] = "artifact"

    display_image_actual = nil

    Rails.stub :root, Pathname.getwd do
      @new_test.stub :save_image, nil do
        @new_test.stub :show, -> (img) { display_image_actual = img } do
          @new_test.take_screenshot
        end
      end
    end

    assert_match %r|url=artifact://.+?tmp/screenshots/1_x\.png|, display_image_actual
  ensure
    ENV["RAILS_SYSTEM_TESTING_SCREENSHOT"] = original_output_type
  end

  test "take_screenshot allows changing screeenshot display format via screenshot: kwarg" do
    display_image_actual = nil

    Rails.stub :root, Pathname.getwd do
      @new_test.stub :save_image, nil do
        @new_test.stub :show, -> (img) { display_image_actual = img } do
          @new_test.take_screenshot(screenshot: "artifact")
        end
      end
    end

    assert_match %r|url=artifact://.+?tmp/screenshots/1_x\.png|, display_image_actual
  end

  test "image path returns the absolute path from root" do
    Rails.stub :root, Pathname.getwd.join("..") do
      assert_equal Rails.root.join("tmp/screenshots/0_x.png").to_s, @new_test.send(:image_path)
    end
  end

  test "slashes and backslashes are replaced with dashes in paths" do
    slash_test = DrivenBySeleniumWithChrome.new("x/y\\z")

    Rails.stub :root, Pathname.getwd do
      assert_equal Rails.root.join("tmp/screenshots/0_x-y-z.png").to_s, slash_test.send(:image_path)
      assert_equal Rails.root.join("tmp/screenshots/0_x-y-z.html").to_s, slash_test.send(:html_path)
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
