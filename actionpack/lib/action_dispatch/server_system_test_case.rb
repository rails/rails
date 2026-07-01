# frozen_string_literal: true

# :markup: markdown

require "action_controller"
require "action_dispatch/system_testing/test_session"
require "action_dispatch/system_testing/url_helpers_proxy"

module ActionDispatch
  # # Server System Testing
  #
  # `ActionDispatch::ServerSystemTestCase` boots your Rails application as a
  # real server for system testing. It does not depend on Capybara.
  #
  # It is responsible only for the part of system testing that genuinely belongs
  # to Rails: booting the application as a real Rack server, binding it to a
  # host/port, waiting until it is actually serving requests, exposing the base
  # URL it is reachable on, and tearing it down at the end of the run. URL
  # helpers (`root_url`, `users_path`, ...) are generated against that running
  # server, so the host they produce points at the live application.
  #
  # Everything above that -- driving a browser, filling in forms, asserting on
  # the page, taking screenshots -- is left to the test author or to a browser
  # automation tool of their choice (Capybara, Playwright, Ferrum, ...).
  # `ActionDispatch::SystemTestCase` provides the familiar Capybara-based
  # experience separately, while sharing the same URL helper behavior.
  #
  # Configure how the application is served, and wire up the browser automation
  # tool of your choice, in your `ApplicationSystemTestCase`, so that individual
  # tests stay focused on the interaction being tested. `served_by` is optional --
  # by default the server binds to an available port on `0.0.0.0`. For example,
  # with Playwright:
  #
  #     require "test_helper"
  #     require "playwright"
  #
  #     class ApplicationSystemTestCase < ActionDispatch::ServerSystemTestCase
  #       # Launch Playwright and the browser once for the whole run; a fresh
  #       # browser context per test is enough to isolate one test from the next,
  #       # and is far cheaper than relaunching the browser each time.
  #       def self.browser
  #         @browser ||= begin
  #           execution = Playwright.create(playwright_cli_executable_path: "npx playwright")
  #           at_exit { execution.stop }
  #           execution.playwright.chromium.launch
  #         end
  #       end
  #
  #       setup do
  #         @context = ApplicationSystemTestCase.browser.new_context
  #         @page = @context.new_page
  #       end
  #
  #       teardown { @context&.close }
  #     end
  #
  # Individual tests then only drive the page. URL helpers (`root_url`,
  # `new_user_url`, ...) are generated against the running server, so they point
  # at the live application:
  #
  #     require "application_system_test_case"
  #
  #     class UsersTest < ApplicationSystemTestCase
  #       test "creating a user" do
  #         @page.goto new_user_url # => http://127.0.0.1:<port>/users/new
  #
  #         @page.fill "input[name='user[name]']", "Arya"
  #         @page.click "text=Create User"
  #
  #         assert_includes @page.content, "Arya"
  #       end
  #     end
  #
  # Any browser automation tool works the same way; only the
  # `ApplicationSystemTestCase` wiring changes.
  #
  # Because the running server is reachable over plain HTTP, a test does not even
  # need a browser. `base_url` (aliased as `app_host`) points at the live
  # application, so an HTTP client such as Faraday can drive it directly:
  #
  #     class ApplicationSystemTestCase < ActionDispatch::ServerSystemTestCase
  #       setup { @client = Faraday.new(url: base_url) }
  #     end
  #
  # and using `@client` in tests (`@client.get("/up")`, ...).
  #
  # The application server is booted before each system test starts. The first
  # test in the process starts the shared test session; later tests reuse it.
  class ServerSystemTestCase < ActiveSupport::TestCase
    include SystemTesting::UrlHelpersProxy

    class << self
      # Configures how the Rails application is served. By default it binds to
      # an available port on `0.0.0.0`, so most suites never need to call this.
      #
      # When the browser must reach the application at a different URL than the
      # bind address -- for example from another Docker container -- set
      # `app_host`:
      #
      #     served_by app_host: "http://rails-app:4000", port: 4000
      def served_by(host: "0.0.0.0", port: 0, app_host: nil)
        SystemTesting.test_session.configure(host: host, port: port, app_host: app_host)
      end
    end

    # Returns the base URL used as the host for URL helpers.
    def base_url
      test_session.app_host
    end
    alias_method :app_host, :base_url

    def before_setup
      test_session.start
      test_session.clear_server_errors
      super
    end

    def after_teardown
      test_session.raise_server_errors
    ensure
      super
    end

    private
      def test_session
        SystemTesting.test_session
      end

      def url_helpers
        @url_helpers ||=
          if ActionDispatch.test_app
            Class.new do
              include ActionDispatch.test_app.routes.url_helpers
              include ActionDispatch.test_app.routes.mounted_helpers

              def url_options
                default_url_options.reverse_merge(host: ActionDispatch::SystemTesting.test_session.app_host)
              end
            end.new
          end
      end
  end
end

# Stop every server booted during the run once the suite is finished.
Minitest.after_run do
  ActionDispatch::SystemTesting.test_session.shutdown
end
