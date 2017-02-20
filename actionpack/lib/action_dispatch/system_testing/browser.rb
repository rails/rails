module ActionDispatch
  module SystemTesting
    class Browser # :nodoc:
      def initialize(name, screen_size)
        @name = name
        @screen_size = screen_size
      end

      def run
        register
        setup
      end

      private
        def register
          Capybara.register_driver @name do |app|
            Capybara::Selenium::Driver.new(app, browser: @name).tap do |driver|
              driver.browser.manage.window.size = Selenium::WebDriver::Dimension.new(*@screen_size)
            end
          end
        end

        def setup
          Capybara.default_driver = @name.to_sym
        end
    end
  end
end
