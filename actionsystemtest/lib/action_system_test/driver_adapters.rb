module ActionSystemTest
  # == System Testing Driver Adapters
  #
  # By default Rails supports Capybara with the Selenium Driver. Rails provides
  # configuration setup for using the selenium driver with Capybara.
  # Additionally Rails can be used as a layer between Capybara and its other
  # supported drivers: +:rack_test+, +:selenium+, +:webkit+, or +:poltergeist+.
  #
  # *{RackTest}[https://github.com/jnicklas/capybara#racktest]
  # *{Selenium}[http://seleniumhq.org/docs/01_introducing_selenium.html#selenium-2-aka-selenium-webdriver]
  # *{Webkit}[https://github.com/thoughtbot/capybara-webkit]
  # *{Poltergeist}[https://github.com/teampoltergeist/poltergeist]
  #
  # === Driver Features
  #
  # |                 | Default Browser       | Supports Screenshots? |
  # |-----------------|-----------------------|-----------------------|
  # | Rails' Selenium | Chrome                | Yes                   |
  # | Rack Test       | No JS Support         | No                    |
  # | Selenium        | Firefox               | Yes                   |
  # | WebKit          | Headless w/ Qt        | Yes                   |
  # | Poltergeist     | Headless w/ PhantomJS | Yes                   |
  module DriverAdapters
    extend ActiveSupport::Autoload

    autoload :CapybaraDriver
    autoload :RailsSeleniumDriver

    class << self
      # Returns driver for specified name.
      #
      #   ActionSystemTest::DriverAdapters.lookup(:rails_selenium_driver)
      #   # => ActionSystemTest::DriverAdapters::RailsSeleniumDriver
      def lookup(driver)
        if CapybaraDriver::CAPYBARA_DEFAULTS.include?(driver)
          CapybaraDriver.new(name: driver)
        elsif driver.is_a?(Symbol)
          klass = const_get(driver.to_s.camelize)
          klass.new
        else
          driver
        end
      end
    end
  end
end
