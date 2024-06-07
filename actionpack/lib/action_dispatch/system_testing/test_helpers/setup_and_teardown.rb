# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module SystemTesting
    module TestHelpers
      module SetupAndTeardown # :nodoc:
        def before_teardown
          take_failed_screenshot
        ensure
          super
        end

        def after_teardown
          Capybara.reset_sessions!
        ensure
          super
        end
      end
    end
  end
end
