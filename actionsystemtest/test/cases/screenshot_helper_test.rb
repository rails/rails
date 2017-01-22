require "active_support/testing/autorun"
require "action_system_test"

class ScreenshotHelperTest < ActiveSupport::TestCase
  test "image path is saved in tmp directory" do
    new_test = ActionSystemTest::Base.new("x")

    assert_equal "tmp/screenshots/failures_x.png", new_test.send(:image_path)
  end
end
