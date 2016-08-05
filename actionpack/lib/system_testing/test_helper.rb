require 'capybara/rails'

module SystemTesting
  module TestHelper
    include Capybara::DSL

    def after_teardown
      Capybara.reset_sessions!
      super
    end
  end
end
