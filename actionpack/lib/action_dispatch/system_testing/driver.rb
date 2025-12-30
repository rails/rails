# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module SystemTesting
    class Driver # :nodoc:
      attr_reader :name

      def initialize(driver_type, **options, &capabilities)
        @driver_type = driver_type
        @screen_size = options[:screen_size]
        @options = options[:options] || {}
        @name = @options.delete(:name) || driver_type
        @capabilities = capabilities

        if driver_type == :selenium
          gem "selenium-webdriver", ">= 4.0.0"
          require "selenium/webdriver"
          @browser = Browser.new(options[:using])
          @browser.preload unless @options[:browser] == :remote
        else
          @browser = nil
        end
      end

      def use
        register if registerable?

        setup
      end

      private
        def registerable?
          [:selenium, :cuprite, :rack_test, :playwright].include?(@driver_type)
        end

        def register
          @browser&.configure(&@capabilities)

          Capybara.register_driver name do |app|
            case @driver_type
            when :selenium then register_selenium(app)
            when :cuprite then register_cuprite(app)
            when :rack_test then register_rack_test(app)
            when :playwright then register_playwright(app)
            end
          end
        end

        def browser_options
          @options.merge(options: @browser.options).compact
        end

        def register_selenium(app)
          Capybara::Selenium::Driver.new(app, browser: @browser.type, **browser_options).tap do |driver|
            driver.browser.manage.window.size = Selenium::WebDriver::Dimension.new(*@screen_size)
          end
        end

        def register_cuprite(app)
          Capybara::Cuprite::Driver.new(app, @options.merge(window_size: @screen_size))
        end

        def register_rack_test(app)
          Capybara::RackTest::Driver.new(app, respect_data_method: true, **@options)
        end

        def register_playwright(app)
          screen = { width: @screen_size[0], height: @screen_size[1] } if @screen_size
          options = {
            screen: screen,
            viewport: screen,
            **@options
          }.compact

          Capybara::Playwright::Driver.new(app, **options)
        end

        def setup
          Capybara.current_driver = name
        end
    end
  end
end
