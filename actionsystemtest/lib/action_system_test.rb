#--
## Copyright (c) 2014-2017 David Heinemeier Hansson
##
## Permission is hereby granted, free of charge, to any person obtaining
## a copy of this software and associated documentation files (the
## "Software"), to deal in the Software without restriction, including
## without limitation the rights to use, copy, modify, merge, publish,
## distribute, sublicense, and/or sell copies of the Software, and to
## permit persons to whom the Software is furnished to do so, subject to
## the following conditions:
##
## The above copyright notice and this permission notice shall be
## included in all copies or substantial portions of the Software.
##
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
## EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
## MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
## NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
## LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
## OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
## WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
##++

require "capybara/dsl"
require "action_controller"
require "action_system_test/driver"
require "action_system_test/browser"
require "action_system_test/server"
require "action_system_test/test_helpers/screenshot_helper"

module ActionSystemTest # :nodoc:
  # = Action System Test
  #
  # System tests let you test real application in the browser. Because system tests
  # use a real browser experience you can test all of your JavaScript easily
  # from your test suite.
  #
  # To create an ActionSystemTest in your application, extend your test class
  # from <tt>ActionSystemTestCase</tt>. System tests use Capybara as a base and
  # allow you to configure the settings through your <tt>system_test_helper.rb</tt>
  # file that is generated with a new application or scaffold.
  #
  # Here is an example system test:
  #
  #   require 'system_test_helper'
  #
  #   class Users::CreateTest < ActionSystemTestCase
  #     test "adding a new user" do
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
  # be generated containing the base class for system testing. This is where you
  # can change the driver, add Capybara settings, and other configuration for
  # your system tests.
  #
  #   require "test_helper"
  #
  #   class ActionSystemTestCase < ActionSystemTest::Base
  #     teardown do
  #       take_failed_screenshot
  #       Capybara.reset_sessions!
  #     end
  #   end
  #
  # By default, <tt>ActionSystemTest</tt> is driven by the Selenium driver, with
  # the Chrome browser, and a browser size of 1400x1400.
  #
  # Changing the driver configuration options are easy. Let's say you want to use
  # and the Firefox browser instead. In your +system_test_helper.rb+
  # file add the following:
  #
  #   require "test_helper"
  #
  #   class ActionSystemTestCase < ActionSystemTest::Base
  #     driven_by :selenium, using: :firefox
  #
  #     teardown do
  #       take_failed_screenshot
  #       Capybara.reset_sessions!
  #     end
  #   end
  #
  # +driven_by+ has a required argument for the driver name. The keyword
  # arguments are +:using+ for the browser (not applicable for headless drivers),
  # and +:screen_size+ to change the size of the screen taking screenshots.
  #
  # To use a headless driver, like Poltergeist, update your Gemfile to use
  # Poltergeist instead of Selenium and then declare the driver name in the
  # +system_test_helper.rb+ file. In this case you would leave out the +:using+
  # option because the driver is headless.
  #
  #   require "test_helper"
  #   require "capybara/poltergeist"
  #
  #   class ActionSystemTestCase < ActionSystemTest::Base
  #     driven_by :poltergeist
  #
  #     teardown do
  #       take_failed_screenshot
  #       Capybara.reset_sessions!
  #     end
  #   end
  #
  # Because <tt>ActionSystemTest</tt> is a shim between Capybara and Rails, any
  # driver that is supported by Capybara is supported by Action System Test as
  # long as you include the required gems and files.
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

    # Action System Test configuration options
    #
    # The defaults settings are Selenium, using Chrome, with a screen size
    # of 1400x1400.
    #
    # Examples:
    #
    #   driven_by :poltergeist
    #
    #   driven_by :selenium, using: :firefox
    #
    #   driven_by :selenium, screen_size: [800, 800]
    def self.driven_by(driver, using: :chrome, screen_size: [1400, 1400])
      Driver.new(driver).run
      Server.new.run
      Browser.new(using, screen_size).run if selenium?(driver)
    end

    def self.selenium?(driver) # :nodoc:
      driver == :selenium
    end
  end

  Base.start_application
  Base.driven_by :selenium
end
