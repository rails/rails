require "action_system_test/driver_adapters/web_server"

module ActionSystemTest
  module DriverAdapters
    # == CapybaraDriver for System Testing
    #
    # The <tt>CapybaraDriver</tt> is a shim that sits between Rails and
    # Capybara.
    #
    # The drivers Capybara supports are: +:rack_test+, +:selenium+, +:webkit+,
    # and +:poltergeist+.
    #
    # Rails provides its own defaults for Capybara with the Selenium driver
    # through <tt>RailsSeleniumDriver</tt>, but allows users to use Selenium
    # directly.
    #
    # To set your system tests to use one of Capybara's default drivers, add
    # the following to yur Rails' configuration test environment:
    #
    #   config.system_testing.driver = :rack_test
    #
    # The +:rack_test+ driver is a basic test driver that doesn't support
    # JavaScript testing and doesn't require a server.
    #
    # The +:poltergeist+ and +:webkit+ drivers are headless, but require some
    # extra environment setup. Because the default server for Rails is Puma, each
    # of the Capybara drivers will default to using Puma. Changing the configuration
    # to use Webrick is possible by initalizing a new driver object.
    #
    # The default settings for the <tt>CapybaraDriver</tt> are:
    #
    #   #<ActionSystemTest::DriverAdapters::CapybaraDriver:0x007ff0e992c1d8
    #     @name=:rack_test,
    #     @server=:puma,
    #     @port=28100
    #    >
    #
    # The settings for the <tt>CapybaraDriver</tt> can be changed from
    # Rails' configuration file.
    #
    #   config.system_testing.driver = ActionSystemTest::DriverAdapters::CapybaraDriver.new(
    #     name: :webkit,
    #     server: :webrick
    #   )
    class CapybaraDriver
      include WebServer

      CAPYBARA_DEFAULTS = [ :rack_test, :selenium, :webkit, :poltergeist ]

      attr_reader :name, :server, :port

      def initialize(name: :rack_test, server: :puma, port: 28100)
        @name = name
        @server = server
        @port = port
      end

      def call
        registration
        setup
      end

      def supports_screenshots?
        @name != :rack_test
      end

      private
        def registration
          register_server
        end

        def setup
          set_server
          set_port
          set_driver
        end

        def set_driver
          Capybara.default_driver = @name
        end
    end
  end
end
