# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  options = {
    browser: ENV["SELENIUM_DRIVER_URL"].blank? ? :chrome : :remote,
    url: ENV["SELENIUM_DRIVER_URL"].blank? ? nil : ENV["SELENIUM_DRIVER_URL"]
  }
  driven_by :selenium, using: :headless_chrome, options: options
end

Capybara.server = :puma, { Silent: true }
Capybara.server_host = "0.0.0.0" # bind to all interfaces
Capybara.app_host = "http://#{IPSocket.getaddress(Socket.gethostname)}" if ENV["SELENIUM_DRIVER_URL"].present?
