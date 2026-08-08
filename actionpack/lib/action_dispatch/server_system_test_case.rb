# frozen_string_literal: true

# :markup: markdown

require "monitor"
require "action_controller"
require "action_dispatch/system_testing/test_adapter"
require "action_dispatch/system_testing/test_adapters"
require "action_dispatch/system_testing/test_session"
require "action_dispatch/system_testing/url_helpers_proxy"

module ActionDispatch
  # # Server System Testing
  #
  # System tests run your application as a real server so you can interact with
  # it in the browser. `ActionDispatch::ServerSystemTestCase` lets you do that
  # with any browser automation tool -- Playwright, Ferrum, or your own --
  # instead of Capybara.
  #
  # It boots your application on a real port, waits until it is serving
  # requests, and gives you the URL it is running on through `base_url`. URL
  # helpers (`root_url`, `users_path`, ...) point at that running server.
  # Interacting with the page is up to the adapter you select.
  #
  # Extend your `ApplicationSystemTestCase` from it and pick an adapter with
  # `testing_with`. `served_by` is optional -- by default the server binds to an
  # available port on `0.0.0.0`:
  #
  #     require "test_helper"
  #
  #     class ApplicationSystemTestCase < ActionDispatch::ServerSystemTestCase
  #       testing_with :playwright
  #     end
  #
  # Your tests then interact with the page. URL helpers point at the running
  # server, so they reach the live application:
  #
  #     require "application_system_test_case"
  #
  #     class UsersTest < ApplicationSystemTestCase
  #       test "creating a user" do
  #         page.goto new_user_url # => http://127.0.0.1:<port>/users/new
  #
  #         page.get_by_label("Name").fill("Arya")
  #         page.get_by_role("button", name: "Create User").click
  #
  #         assert page.get_by_text("Arya").visible?
  #       end
  #     end
  #
  # A browser library can ship its own adapter, so you interact with the page
  # through its native API instead of a shared driver API.
  #
  # You don't even need a browser. `base_url` (aliased as `app_host`) points at
  # the running application, so an HTTP client such as Faraday can interact with
  # it directly:
  #
  #     class ApplicationSystemTestCase < ActionDispatch::ServerSystemTestCase
  #       setup { @client = Faraday.new(url: base_url) }
  #     end
  #
  # You then use `@client` in your tests (`@client.get("/up")`, ...).
  #
  # The server boots before each system test. The first test in the process
  # starts the shared session; later tests reuse it.
  class ServerSystemTestCase < ActiveSupport::TestCase
    include SystemTesting::UrlHelpersProxy

    # Keep adapter selection isolated between system test base classes, so a
    # test suite can define multiple subclasses that use different adapters.
    class_attribute :test_adapter, instance_accessor: false

    class TestAdapterInstances # :nodoc:
      def initialize
        @adapters = []
        @monitor = Monitor.new
      end

      def <<(adapter)
        @monitor.synchronize { @adapters << adapter }
        adapter
      end

      def shutdown_all
        adapters = @monitor.synchronize do
          pending = @adapters.reverse
          @adapters.clear
          pending
        end
        first_error = nil

        adapters.each do |adapter|
          adapter.shutdown
        rescue => error
          first_error ||= error
        end

        raise first_error if first_error
      end
    end

    TEST_ADAPTER_INSTANCES = TestAdapterInstances.new

    class << self
      # Shuts down every adapter installed by testing_with, running the teardown
      # callbacks registered by their global helpers. Runs at the end of the
      # test run.
      def shutdown_all_test_adapters # :nodoc:
        TEST_ADAPTER_INSTANCES.shutdown_all
      end

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

      # Selects the adapter that provides browser objects to system tests.
      #
      #     testing_with :playwright
      #
      # Adapter options are forwarded to the adapter:
      #
      #     testing_with :playwright, browser_type: :firefox, headless: false
      def testing_with(adapter_name, **options)
        adapter_class = SystemTesting::TestAdapters.lookup(adapter_name)
        adapter = adapter_class.new(**options)
        TEST_ADAPTER_INSTANCES << adapter
        adapter.install(self)
        self.test_adapter = adapter
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
      self.class.test_adapter&.before_setup
      super
    end

    def after_teardown
      begin
        self.class.test_adapter&.after_teardown
      ensure
        test_session.raise_server_errors
      end
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

Minitest.after_run do
  ActionDispatch::ServerSystemTestCase.shutdown_all_test_adapters
ensure
  ActionDispatch::SystemTesting.test_session.shutdown
end

# Parallel test workers do not run Minitest's after_run hooks.
ActiveSupport::Testing::Parallelization.run_cleanup_hook do
  ActionDispatch::ServerSystemTestCase.shutdown_all_test_adapters
ensure
  ActionDispatch::SystemTesting.test_session.shutdown
end
