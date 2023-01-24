# frozen_string_literal: true

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

        if [:poltergeist, :webkit].include?(driver_type)
          ActiveSupport::Deprecation.warn <<~MSG.squish
            Poltergeist and capybara-webkit are not maintained already.
            Driver registration of :poltergeist or :webkit is deprecated and will be removed in Rails 7.1.
            You can still use :selenium, and also :cuprite is available for alternative to Poltergeist.
          MSG
        end

        if driver_type == :selenium
          gem "selenium-webdriver", ">= 4.0.0"
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
          [:selenium, :poltergeist, :webkit, :cuprite, :rack_test].include?(@driver_type)
        end

        def register
          @browser&.configure(&@capabilities)

          Capybara.register_driver name do |app|
            case @driver_type
            when :selenium then register_selenium(app)
            when :poltergeist then register_poltergeist(app)
            when :webkit then register_webkit(app)
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

        def register_poltergeist(app)
          Capybara::Poltergeist::Driver.new(app, @options.merge(window_size: @screen_size))
        end

        def register_webkit(app)
          Capybara::Webkit::Driver.new(app, Capybara::Webkit::Configuration.to_hash.merge(@options)).tap do |driver|
            driver.resize_window_to(driver.current_window_handle, *@screen_size)
          end
        end

        def register_cuprite(app)
          Capybara::Cuprite::Driver.new(app, @options.merge(window_size: @screen_size))
        end

        def register_rack_test(app)
          Capybara::RackTest::Driver.new(app, respect_data_method: true, **@options)
        end

        def setup
          Capybara.current_driver = name
        end
    end
  end
end
