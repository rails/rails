require "action_dispatch/system_testing/driver"

module ActionDispatch
  module SystemTesting
    class Browser < Driver # :nodoc:
      def initialize(name, screen_size)
        super(name)
        @name = name
        @screen_size = screen_size
      end

      def use
        register
        super
      end

      private
        def register
          Capybara.register_driver @name do |app|
            Capybara::Selenium::Driver.new(app, browser: @name).tap do |driver|
              driver.browser.manage.window.size = Selenium::WebDriver::Dimension.new(*@screen_size)
            end
          end
        end
    end
  end
end
