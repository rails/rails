require "abstract_unit"
require "action_dispatch/system_testing/test_helpers/screenshot_helper"
require "capybara/dsl"

class ScreenshotHelperTest < ActiveSupport::TestCase
  test "image path is saved in tmp directory" do
    new_test = ActionDispatch::SystemTestCase.new("x")

    assert_equal "tmp/screenshots/x.png", new_test.send(:image_path)
  end

  test "image path includes failures text if test did not pass" do
    new_test = ActionDispatch::SystemTestCase.new("x")

    new_test.stub :passed?, false do
      assert_equal "tmp/screenshots/failures_x.png", new_test.send(:image_path)
    end
  end

  test "image path does not include failures text if test skipped" do
    new_test = ActionDispatch::SystemTestCase.new("x")

    new_test.stub :passed?, false do
      new_test.stub :skipped?, true do
        assert_equal "tmp/screenshots/x.png", new_test.send(:image_path)
      end
    end
  end

  test "rack_test driver does not support screenshot" do
    begin
      original_driver = Capybara.current_driver
      Capybara.current_driver = :rack_test

      new_test = ActionDispatch::SystemTestCase.new("x")
      assert_not new_test.send(:supports_screenshot?)
    ensure
      Capybara.current_driver = original_driver
    end
  end

  test "selenium driver supports screenshot" do
    begin
      original_driver = Capybara.current_driver
      Capybara.current_driver = :selenium

      new_test = ActionDispatch::SystemTestCase.new("x")
      assert new_test.send(:supports_screenshot?)
    ensure
      Capybara.current_driver = original_driver
    end
  end
end
