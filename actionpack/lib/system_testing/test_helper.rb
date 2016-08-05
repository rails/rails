require 'capybara/rails'
require 'system_testing/test_helpers'

module SystemTesting
  module TestHelper
    include Capybara::DSL
    include TestHelpers::FormHelper

    def after_teardown
      Capybara.reset_sessions!
      super
    end
  end
end
