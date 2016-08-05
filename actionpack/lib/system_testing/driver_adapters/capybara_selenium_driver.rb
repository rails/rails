require 'rack/handler/puma'
require 'selenium-webdriver'

module SystemTesting
  module DriverAdapters
    class CapybaraSeleniumDriver
      attr_reader :browser, :server, :port, :screen_size

      def initialize(browser: :chrome, server: :puma, port: 28100, screen_size: [1400,1400])
        @browser     = browser
        @server      = server
        @port        = port
        @screen_size = screen_size
      end

      def call
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
