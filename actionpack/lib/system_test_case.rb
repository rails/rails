require 'system_testing/test_helper'
require 'system_testing/driver_adapter'

module Rails
  # System tests are similar to Integration tests in that they incorporate multiple
  # controllers and actions, but can be used to similate a real user experience.
  # System tests are also known as Acceptance tests.
  #
  # To create a System Test in your application extend your test class from
  # <tt>Rails::SystemTestCase</tt>. System tests use Capybara as a base and
  # allows you to configure the driver. The default driver is RackTest.
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
  # System tests in your application can be configured to use different drivers.
  #
  # To specify a driver, add the following to your Rails' configuration file for
  # the test environment.
  #
  #   config.system_testing.driver = :capybara_selenium_driver
  #
  # You can also specify a driver with a new driver object. Through this method
  # you can also change the default settings for the driver you're setting.
  #
  #   config.system_testing.driver = SystemTesting::DriverAdapters::CapybaraRackTestDriver.new(
  #     useragent: 'My Useragent'
  #   )
  #
  # A list of supported adapters can be found in DriverAdapters.
  #
  # If you want to use a driver that is not supported by Rails but is available
  # in Capybara, you can override Rails settings and use Capybara directly by
  # setting the +Capybara.default_driver+ and +Capybara.javascript_driver+ in
  # your test_help file.
  #
  # You can also skip using Rails system tests completely by not inheriting from
  # <tt>Rails::SystemTestCase</tt> and following Capybara's instructions.
  class SystemTestCase < ActionDispatch::IntegrationTest
    include SystemTesting::TestHelper
    include SystemTesting::DriverAdapter

    ActiveSupport.run_load_hooks(:system_testing, self)
  end
end
