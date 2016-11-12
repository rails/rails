require "action_system_test/driver_adapters/web_server"

module ActionSystemTest
  module DriverAdapters
    # == RailsSeleniumDriver for Action System Test
    #
    # The <tt>RailsSeleniumDriver</tt> uses the Selenium 2.0 webdriver. The
    # selenium-webdriver gem is required by this driver.
    #
    # The <tt>RailsSeleniumDriver</tt> is useful for real browser testing and
    # supports Chrome and Firefox.
    #
    # By default Rails system testing will use Rails' configuration with Capybara
    # and the Selenium driver. To explictly set the <tt>RailsSeleniumDriver</tt>
    # add the following to your +system_test_helper+:
    #
    #   class ActionSystemTest < ActionSystemTest::Base
    #     ActionSystemTest.driver = :rails_selenium_driver
    #   end
    #
    # Because this driver supports real browser testing it is required that a
    # server is configured.
    #
    # If no server is specified when the driver is initialized, Puma will be used
    # by default. The default settings for the <tt>RailsSeleniumDriver</tt>
    # are as follows:
    #
    #   #<ActionSystemTest::DriverAdapters::RailsSeleniumDriver:0x007ff0e992c1d8
    #     @browser=:chrome,
    #     @server=:puma,
    #     @port=28100,
    #     @screen_size=[ 1400, 1400 ]
    #    >
    #
    # The settings for the <tt>RailsSeleniumDriver</tt> can be changed in the
    # +system_test_helper+.
    #
    #   class ActionSystemTest < ActionSystemTest::Base
    #     ActionSystemTest.driver = ActionSystemTest::DriverAdapters::RailsSeleniumDriver.new(
    #       server: :webrick,
    #       port: 28100,
    #       screen_size: [ 800, 800 ]
    #     )
    #   end
    #
    # The default browser is set to Chrome. If you want to use Firefox,
    # you will need to use Firefox 45.0esr or 47.0 and ensure
    # that selenium-webdriver is version 2.53.4. To change the browser from
    # +:chrome+ to +:firefox+, initialize the Selenium driver in your Rails'
    # test environment:
    #
    #   class ActionSystemTest < ActionSystemTest::Base
    #     ActionSystemTest.driver = ActionSystemTest::DriverAdapters::RailsSeleniumDriver.new(
    #       browser: :firefox
    #     )
    #   end
    class RailsSeleniumDriver
      include WebServer

      attr_reader :browser, :server, :port, :screen_size

      def initialize(browser: :chrome, server: :puma, port: 28100, screen_size: [ 1400, 1400 ]) # :nodoc:
        @browser     = browser
        @server      = server
        @port        = port
        @screen_size = screen_size
      end

      def run # :nodoc:
        registration
        setup
      end

      def supports_screenshots?
        true
      end

      private
        def registration
          register_browser_driver
          register_server
        end

        def setup
          set_server
          set_port
          set_driver
        end

        def register_browser_driver
          Capybara.register_driver @browser do |app|
            Capybara::Selenium::Driver.new(app, browser: @browser).tap do |driver|
              driver.browser.manage.window.size = Selenium::WebDriver::Dimension.new(*@screen_size)
            end
          end
        end

        def set_driver
          Capybara.default_driver = @browser.to_sym
        end
    end
  end
end
