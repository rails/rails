# frozen_string_literal: true

require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome
end

ENV["RACK_ENV"] ||= "test" # avoid LeakChecker error when set by Puma
Capybara.server = :puma, { Silent: true }
