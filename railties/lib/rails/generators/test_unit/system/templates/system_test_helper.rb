require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]

  teardown do
    take_failed_screenshot
    Capybara.reset_sessions!
  end
end
