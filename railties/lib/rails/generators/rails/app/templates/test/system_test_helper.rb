require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  teardown do
    take_failed_screenshot
    Capybara.reset_sessions!
  end
end
