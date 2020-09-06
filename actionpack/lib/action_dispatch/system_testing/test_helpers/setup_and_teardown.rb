# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    module TestHelpers
      module SetupAndTeardown # :nodoc:
        def host!(host)
          ActiveSupport::Deprecation.warn \
            'ActionDispatch::SystemTestCase#host! is deprecated with no replacement. ' \
            "Set Capybara.app_host directly or rely on Capybara's default host."

          Capybara.app_host = host
        end

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
