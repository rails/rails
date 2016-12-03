require "capybara/dsl"
require "action_system_test/test_helpers"

module ActionSystemTest
  module TestHelper # :nodoc:
    include TestHelpers::ScreenshotHelper
    include Capybara::DSL

    Capybara.app = Rack::Builder.new do
      map "/" do
        run Rails.application
      end
    end
  end
end
