# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    class Driver # :nodoc:
      def initialize(name, **options, &desired_capabilities)
        @name = name
        @browser = Browser.new(options[:using])
        @screen_size = options[:screen_size]
        @options = options[:options]
        @desired_capabilities = desired_capabilities
      end

      def use
        register if registerable?

        setup
      end

      private
        def registerable?
          [:selenium, :poltergeist, :webkit].include?(@name)
        end

        def register
          define_browser_capabilities(@browser.driver_options)

          Capybara.register_driver @name do |app|
            case @name
            when :selenium then register_selenium(app)
            when :poltergeist then register_poltergeist(app)
            when :webkit then register_webkit(app)
            end
          end
        end

        def define_browser_capabilities(driver_options)
          @desired_capabilities.call(driver_options) if @desired_capabilities
        end

        def browser_options
          @options.merge(options: @browser.options).compact
        end

        def register_selenium(app)
          Capybara::Selenium::Driver.new(app, { browser: @browser.type }.merge(browser_options)).tap do |driver|
            driver.browser.manage.window.size = Selenium::WebDriver::Dimension.new(*@screen_size)
          end
        end

        def register_poltergeist(app)
          Capybara::Poltergeist::Driver.new(app, @options.merge(window_size: @screen_size))
        end

        def register_webkit(app)
          Capybara::Webkit::Driver.new(app, Capybara::Webkit::Configuration.to_hash.merge(@options)).tap do |driver|
            driver.resize_window_to(driver.current_window_handle, *@screen_size)
          end
        end

        def setup
          Capybara.current_driver = @name
        end
    end
  end
end
