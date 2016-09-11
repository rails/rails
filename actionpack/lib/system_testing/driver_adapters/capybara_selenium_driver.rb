require 'rack/handler/puma'
require 'selenium-webdriver'

module SystemTesting
  module DriverAdapters
    # == CapybaraSeleniumDriver for System Testing
    #
    # The <tt>CapybaraSeleniumDriver</t> uses the Selenium 2.0 webdriver. The
    # selenium-webdriver gem is required by this driver.
    #
    # The CapybaraSeleniumDriver is useful for real browser testing and
    # support Chrome and Firefox.
    #
    # To set your system testing to use the Selenium web driver add the
    # following to your Rails' configuration test environment:
    #
    #   config.system_testing.driver = :capybara_selenium_driver
    #
    # Because this driver supports real browser testing it is required that a
    # server is configured.
    #
    # If no server is specified when the driver is initialized, Puma will be used
    # by default. The default settings for the <tt>CapybaraSeleniumDriver</tt>
    # are:
    #
    #   #<SystemTesting::DriverAdapters::CapybaraSeleniumDriver:0x007ff0e992c1d8
    #     @browser=:chrome,
    #     @server=:puma,
    #     @port=28100,
    #     @screen_size=[ 1400, 1400 ]
    #    >
    #
    # The settings for the <tt>CapybaraSeleniumDriver</tt> can be changed from
    # Rails' configuration file.
    #
    #   config.system_testing.driver = SystemTesting::DriverAdapters::CapybaraSeleniumDriver.new(
    #     server: :webkit,
    #     port: 28100,
    #     screen_size: [ 800, 800 ]
    #   )
    #
    # The default browser is set to chrome because the current version of
    # Firefox does not work with selenium-webdriver. If you want to use Firefox,
    # you will need to use Firefox 45.0esr or 47.0 and ensure
    # that selenium-webdriver is version 2.53.4. To change the browser from
    # +:chrome+ to +:firefox+, initialize the selenium driver in your Rails'
    # test environment:
    #
    #   config.system_testing.driver = SystemTesting::DriverAdapters::CapybaraSeleniumDriver.new(
    #     browser: :firefox
    #   )
    class CapybaraSeleniumDriver
      attr_reader :browser, :server, :port, :screen_size

      def initialize(browser: :chrome, server: :puma, port: 28100, screen_size: [1400,1400]) # :nodoc:
        @browser     = browser
        @server      = server
        @port        = port
        @screen_size = screen_size
      end

      def call # :nodoc:
        registration
        setup
      end

      private
        def registration
          register_browser_driver
          register_server
        end

        def setup
          set_server
          set_driver
          set_port
        end

        def register_browser_driver
          Capybara.register_driver @browser do |app|
            Capybara::Selenium::Driver.new(app, browser: @browser).tap do |driver|
              driver.browser.manage.window.size = Selenium::WebDriver::Dimension.new(*@screen_size)
            end
          end
        end

        def register_server
          Capybara.register_server @server do |app, port, host|
            case @server
            when :puma
              register_puma(app, port)
            when :webrick
              register_webrick(app, port, host)
            else
              register_default(app, port)
            end
          end
        end

        def register_default(app, port)
          Capybara.run_default_server(app, port)
        end

        def register_puma(app, port)
          ::Rack::Handler::Puma.run(app, Port: port, Threads: '0:4')
        end

        def register_webrick(app, port, host)
          Rack::Handler::WEBrick.run(app, Host: host, Port: port, AccessLog: [], Logger: WEBrick::Log::new(nil, 0))
        end

        def set_server
          Capybara.server = @server
        end

        def set_driver
          Capybara.default_driver = @browser.to_sym
        end

        def set_port
          Capybara.server_port = @port
        end
    end
  end
end
