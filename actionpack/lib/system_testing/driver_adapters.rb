module SystemTesting
  # == System Testing Driver Adapters
  #
  # System testing supports the following drivers:
  #
  # * {RackTest}[https://github.com/brynary/rack-test]
  # * {Selenium}[https://github.com/SeleniumHQ/selenium]
  module DriverAdapters
    extend ActiveSupport::Autoload

    autoload :CapybaraRackTestDriver
    autoload :CapybaraSeleniumDriver

    class << self
      # Returns driver for specified name.
      #
      #   SystemTesting::DriverAdapters.lookup(:capybara_selenium_driver)
      #   # => SystemTesting::DriverAdapters::CapybaraSeleniumDriver
      def lookup(name)
        const_get(name.to_s.camelize)
      end
    end
  end
end
