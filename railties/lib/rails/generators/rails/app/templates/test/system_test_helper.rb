require "test_helper"

class ActionSystemTestCase < ActionSystemTest::Base
  teardown do
    take_failed_screenshot
    Capybara.reset_sessions!
  end
end
