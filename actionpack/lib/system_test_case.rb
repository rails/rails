require 'system_testing/test_helper'
require 'system_testing/driver_adapter'

module Rails
  # System tests are similar to Integration tests in that they incorporate multiple
  # controllers and actions, but can be used to simulate a real user experience.
  # System tests are also known as Acceptance tests.
  #
  # To create a System Test in your application extend your test class from
  # <tt>Rails::SystemTestCase</tt>. System tests use Capybara as a base and
  # allows you to configure the driver. The default driver is
  # <tt>RailsSeleniumDriver</tt> which provides Capybara with no-setup
  # configuration of the Selenium Driver. If you prefer you can use the bare
  # Selenium driver and set your own configuration.
  #
  # A system test looks like the following:
  #
  #   require 'test_helper'
  #
  #   class Users::CreateTest < Rails::SystemTestCase
  #     def adding_a_new_user
  #       visit users_path
  #       click_on 'New User'
  #
  #       fill_in 'Name', with: 'Arya'
  #       click_on 'Create User'
  #
  #       assert_text 'Arya'
  #     end
  #   end
  #
  # System test driver can be configured in your Rails configuration file for the
  # test environment.
  #
  #   config.system_testing.driver = :rails_selenium_driver
  #
  # You can also specify a driver by initializing a new driver object. This allows
  # you to change the default settings for the driver you're setting.
  #
  #   config.system_testing.driver = SystemTesting::DriverAdapters::RailsSeleniumDriver.new(
  #     browser: :firefox
  #   )
  #
  # A list of supported adapters can be found in DriverAdapters.
  #
  # If you want to use one of the default drivers provided by Capybara you can
  # set the driver in your config to one of those defaults: +:rack_test+,
  # +:selenium+, +:webkit+, or +:poltergeist+. These 4 drivers use Capyara's
  # driver defaults whereas the <tt>RailsSeleniumDriver</tt> has pre-set
  # configuration for browser, server, port, etc.
  class SystemTestCase < ActionDispatch::IntegrationTest
    include SystemTesting::TestHelper
    include SystemTesting::DriverAdapter

    ActiveSupport.run_load_hooks(:system_testing, self)
  end
end
