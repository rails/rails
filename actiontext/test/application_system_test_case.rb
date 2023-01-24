# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome do |driver_option|
    driver_option.add_argument("--no-sandbox")
  end
end

Capybara.server = :puma, { Silent: true }
