# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    class Driver # :nodoc:
      def initialize(name, **options, &capabilities)
        @name = name
        @screen_size = options[:screen_size]
        @options = options[:options] || {}
        @capabilities = capabilities

        if name == :selenium
          require "selenium/webdriver"
          @browser = Browser.new(options[:using])
          @browser.preload
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
          [:selenium, :cuprite, :rack_test].include?(@name)
        end

        def register
          @browser&.configure(&@capabilities)

          Capybara.register_driver @name do |app|
            case @name
            when :selenium then register_selenium(app)
            when :cuprite then register_cuprite(app)
            when :rack_test then register_rack_test(app)
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

        def setup
          Capybara.current_driver = @name
        end
    end
  end
end
