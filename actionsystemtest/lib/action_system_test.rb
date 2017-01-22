# System tests are similar to Integration tests in that they incorporate multiple
# controllers and actions, but can be used to simulate a real user experience.
# System tests are also known as Acceptance tests.
#
# To create a System Test in your application, extend your test class from
# <tt>ActionSystemTestCase</tt>. System tests use Capybara as a base and
# allow you to configure the driver. The default driver is
# <tt>RailsSeleniumDriver</tt> which provides a Capybara and the Selenium
# Driver with no configuration. It's intended to work out of the box.
#
# A system test looks like the following:
#
#   require 'system_test_helper'
#
#   class Users::CreateTest < ActionSystemTestCase
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
# When generating an application or scaffold a +system_test_helper.rb+ will also
# be generated containing the base class for system testing. This is where you can
# change the driver, add Capybara settings, and other configuration for your system
# tests.
#
#   class ActionSystemTestCase < ActionSystemTest::Base
#     ActionSystemTest.driver = :rack_test
#   end
#
# You can also specify a driver by initializing a new driver object. This allows
# you to change the default settings for the driver you're setting.
#
#   class ActionSystemTestCase < ActionSystemTest::Base
#     ActionSystemTest.driver = ActionSystemTest::DriverAdapters::RailsSeleniumDriver.new(
#       browser: :firefox
#     )
#   end
#
# A list of supported adapters can be found in DriverAdapters.
#
# If you want to use one of the default drivers provided by Capybara you can
# set the driver in your config to one of those defaults: +:rack_test+,
# +:selenium+, +:webkit+, or +:poltergeist+. These 4 drivers use Capyara's
# driver defaults whereas the <tt>RailsSeleniumDriver</tt> has pre-set
# configuration for browser, server, port, etc.

require "capybara/dsl"
require "action_controller"
require "action_system_test/driver"
require "action_system_test/browser"
require "action_system_test/server"
require "action_system_test/test_helpers/screenshot_helper"

module ActionSystemTest
  include Capybara::DSL
  include ActionSystemTest::TestHelpers::ScreenshotHelper

  class Base < ActionDispatch::IntegrationTest
    include ActionSystemTest

    def self.start_application # :nodoc:
      Capybara.app = Rack::Builder.new do
        map "/" do
          run Rails.application
        end
      end
    end

    def self.driven_by(driver, using: :chrome, on: 21800, screen_size: [1400, 1400])
      Driver.new(driver).run
      Server.new(on).run
      Browser.new(using, screen_size).run if selenium?(driver)
    end

    def self.selenium?(driver) # :nodoc:
      driver == :selenium
    end
  end

  Base.start_application
  Base.driven_by :selenium
end
