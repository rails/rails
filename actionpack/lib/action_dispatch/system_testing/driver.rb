# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    class Driver # :nodoc:
      def initialize(name, **options)
        @name = name
        @browser = options[:using]
        @screen_size = options[:screen_size]
        @options = options[:options]
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
          Capybara.register_driver @name do |app|
            case @name
            when :selenium then register_selenium(app)
            when :poltergeist then register_poltergeist(app)
            when :webkit then register_webkit(app)
            end
          end
        end

        def browser_options
          if @browser == :headless_chrome
            browser_options = Selenium::WebDriver::Chrome::Options.new
            browser_options.args << "--headless"
            browser_options.args << "--disable-gpu"

            @options.merge(options: browser_options)
          elsif @browser == :headless_firefox
            browser_options = Selenium::WebDriver::Firefox::Options.new
            browser_options.args << "-headless"

            @options.merge(options: browser_options)
          else
            @options
          end
        end

        def browser
          if @browser == :headless_chrome
            :chrome
          elsif @browser == :headless_firefox
            :firefox
          else
            @browser
          end
        end

        def register_selenium(app)
          Capybara::Selenium::Driver.new(app, { browser: browser }.merge(browser_options)).tap do |driver|
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
