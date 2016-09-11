require 'capybara/dsl'
require 'system_testing/test_helpers'

module SystemTesting
  module TestHelper # :nodoc:
    include TestHelpers::FormHelper
    include TestHelpers::Assertions
    include Capybara::DSL

    Capybara.app = Rack::Builder.new do
      map "/" do
        run Rails.application
      end
    end

    def after_teardown
      Capybara.reset_sessions!
      super
    end
  end
end
