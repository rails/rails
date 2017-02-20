module ActionDispatch
  module SystemTesting
    module TestHelpers
      module SetupAndTeardown # :nodoc:
        DEFAULT_HOST = "127.0.0.1"

        def before_setup
          host! DEFAULT_HOST
          super
        end

        def after_teardown
          super
          take_failed_screenshot
          Capybara.reset_sessions!
        end
      end
    end
  end
end
