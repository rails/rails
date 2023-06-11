# frozen_string_literal: true

ENV["RAILS_ENV"] = "test"

require_relative "../test/dummy/config/environment"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome
end

Capybara.server = :puma, { Silent: true }
