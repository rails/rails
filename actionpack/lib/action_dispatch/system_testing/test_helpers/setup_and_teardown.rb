# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    module TestHelpers
      module SetupAndTeardown # :nodoc:
        DEFAULT_HOST = "http://127.0.0.1"

        def host!(host)
          super
          Capybara.app_host = host
        end

        def before_setup
          host! app_host
          super
        end

        def after_teardown
          take_failed_screenshot
          Capybara.reset_sessions!
          super
        end

        private

          def app_host
            Capybara.app_host || DEFAULT_HOST
          end
      end
    end
  end
end
