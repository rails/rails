module ActionDispatch
  module SystemTesting
    class Driver # :nodoc:
      def initialize(name, **options)
        @name = name
        @browser = options[:using]
        @screen_size = options[:screen_size]
      end

      def use
        register if selenium?
        setup
      end

      def reset
        Capybara.current_driver = @current
      end

      private
        def selenium?
          @name == :selenium
        end

        def register
          Capybara.register_driver @name do |app|
            Capybara::Selenium::Driver.new(app, browser: @browser).tap do |driver|
              driver.browser.manage.window.size = Selenium::WebDriver::Dimension.new(*@screen_size)
            end
          end
        end

        def setup
          Capybara.current_driver = @name
          @current = Capybara.current_driver
        end
    end
  end
end
