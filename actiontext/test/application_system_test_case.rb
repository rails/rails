# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  options = ENV["SELENIUM_DRIVER_URL"].present? ? { url: ENV["SELENIUM_DRIVER_URL"] } : {}
  driven_by :selenium, using: :headless_chrome, options: options
end

Capybara.server = :puma, { Silent: true }
