module SystemTesting
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
    #   #<SystemTesting::DriverAdapters::CapybaraDriver:0x007ff0e992c1d8
    #     @name=:rack_test,
    #     @server=:puma,
    #     @port=28100
    #    >
    #
    # The settings for the <tt>CapybaraDriver</tt> can be changed from
    # Rails' configuration file.
    #
    #   config.system_testing.driver = SystemTesting::DriverAdapters::CapybaraDriver.new(
    #     name: :webkit,
    #     server: :webrick
    #   )
    class CapybaraDriver
      CAPYBARA_DEFAULTS = [ :rack_test, :selenium, :webkit, :poltergeist ]

      attr_reader :name

      def initialize(name)
        @name = name
      end

      def call
        Capybara.default_driver = @name
      end

      def supports_screenshots?
        @name != :rack_test
      end
    end
  end
end
