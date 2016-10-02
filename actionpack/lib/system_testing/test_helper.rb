require 'capybara/dsl'
require 'system_testing/test_helpers'

module SystemTesting
  module TestHelper # :nodoc:
    include TestHelpers::Assertions
    include TestHelpers::FormHelper
    include TestHelpers::ScreenshotHelper
    include Capybara::DSL

    Capybara.app = Rack::Builder.new do
      map "/" do
        run Rails.application
      end
    end

    def after_teardown
      take_screenshot if supported?
      Capybara.reset_sessions!
      super
    end
  end
end
