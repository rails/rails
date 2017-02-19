require "abstract_unit"
require "action_dispatch/system_testing/test_helpers/screenshot_helper"

class ScreenshotHelperTest < ActiveSupport::TestCase
  test "image path is saved in tmp directory" do
    new_test = ActionDispatch::SystemTestCase.new("x")

    assert_equal "tmp/screenshots/failures_x.png", new_test.send(:image_path)
  end
end
