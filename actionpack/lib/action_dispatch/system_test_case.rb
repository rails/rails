# frozen_string_literal: true

gem "capybara", ">= 2.15"

require "capybara/dsl"
require "capybara/minitest"
require "selenium/webdriver"
require "action_controller"
require "action_dispatch/system_testing/driver"
require "action_dispatch/system_testing/browser"
require "action_dispatch/system_testing/server"
require "action_dispatch/system_testing/test_helpers/screenshot_helper"
require "action_dispatch/system_testing/test_helpers/setup_and_teardown"
require "action_dispatch/system_testing/test_helpers/undef_methods"

module ActionDispatch
  # = System Testing
  #
  # System tests let you test applications in the browser. Because system
  # tests use a real browser experience, you can test all of your JavaScript
  # easily from your test suite.
  #
  # To create a system test in your application, extend your test class
  # from <tt>ApplicationSystemTestCase</tt>. System tests use Capybara as a
  # base and allow you to configure the settings through your
  # <tt>application_system_test_case.rb</tt> file that is generated with a new
  # application or scaffold.
  #
  # Here is an example system test:
  #
  #   require 'application_system_test_case'
  #
  #   class Users::CreateTest < ApplicationSystemTestCase
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
  # When generating an application or scaffold, an +application_system_test_case.rb+
  # file will also be generated containing the base class for system testing.
  # This is where you can change the driver, add Capybara settings, and other
  # configuration for your system tests.
  #
  #   require "test_helper"
  #
  #   class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  #     driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
  #   end
  #
  # By default, <tt>ActionDispatch::SystemTestCase</tt> is driven by the
  # Selenium driver, with the Chrome browser, and a browser size of 1400x1400.
  #
  # Changing the driver configuration options is easy. Let's say you want to use
  # the Firefox browser instead of Chrome. In your +application_system_test_case.rb+
  # file add the following:
  #
  #   require "test_helper"
  #
  #   class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  #     driven_by :selenium, using: :firefox
  #   end
  #
  # +driven_by+ has a required argument for the driver name. The keyword
  # arguments are +:using+ for the browser and +:screen_size+ to change the
  # size of the browser screen. These two options are not applicable for
  # headless drivers and will be silently ignored if passed.
  #
  # Headless browsers such as headless Chrome and headless Firefox are also supported.
  # You can use these browsers by setting the +:using+ argument to +:headless_chrome+ or +:headless_firefox+.
  #
  # To use a headless driver, like Poltergeist, update your Gemfile to use
  # Poltergeist instead of Selenium and then declare the driver name in the
  # +application_system_test_case.rb+ file. In this case, you would leave out
  # the +:using+ option because the driver is headless, but you can still use
  # +:screen_size+ to change the size of the browser screen, also you can use
  # +:options+ to pass options supported by the driver. Please refer to your
  # driver documentation to learn about supported options.
  #
  #   require "test_helper"
  #   require "capybara/poltergeist"
  #
  #   class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  #     driven_by :poltergeist, screen_size: [1400, 1400], options:
  #       { js_errors: true }
  #   end
  #
  # Some drivers require browser capabilities to be passed as a block instead
  # of through the +options+ hash.
  #
  # As an example, if you want to add mobile emulation on chrome, you'll have to
  # create an instance of selenium's +Chrome::Options+ object and add
  # capabilities with a block.
  #
  # The block will be passed an instance of <tt><Driver>::Options</tt> where you can
  # define the capabilities you want. Please refer to your driver documentation
  # to learn about supported options.
  #
  #   class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  #     driven_by :selenium, using: :chrome, screen_size: [1024, 768] do |driver_option|
  #       driver_option.add_emulation(device_name: 'iPhone 6')
  #       driver_option.add_extension('path/to/chrome_extension.crx')
  #     end
  #   end
  #
  # Because <tt>ActionDispatch::SystemTestCase</tt> is a shim between Capybara
  # and Rails, any driver that is supported by Capybara is supported by system
  # tests as long as you include the required gems and files.
  class SystemTestCase < IntegrationTest
    include Capybara::DSL
    include Capybara::Minitest::Assertions
    include SystemTesting::TestHelpers::SetupAndTeardown
    include SystemTesting::TestHelpers::ScreenshotHelper
    include SystemTesting::TestHelpers::UndefMethods

    def initialize(*) # :nodoc:
      super
      self.class.driver.use
    end

    def self.start_application # :nodoc:
      Capybara.app = Rack::Builder.new do
        map "/" do
          run Rails.application
        end
      end

      SystemTesting::Server.new.run
    end

    class_attribute :driver, instance_accessor: false

    # System Test configuration options
    #
    # The default settings are Selenium, using Chrome, with a screen size
    # of 1400x1400.
    #
    # Examples:
    #
    #   driven_by :poltergeist
    #
    #   driven_by :selenium, screen_size: [800, 800]
    #
    #   driven_by :selenium, using: :chrome
    #
    #   driven_by :selenium, using: :headless_chrome
    #
    #   driven_by :selenium, using: :firefox
    #
    #   driven_by :selenium, using: :headless_firefox
    def self.driven_by(driver, using: :chrome, screen_size: [1400, 1400], options: {}, &capabilities)
      driver_options = { using: using, screen_size: screen_size, options: options }

      self.driver = SystemTesting::Driver.new(driver, driver_options, &capabilities)
    end

    driven_by :selenium

    ActiveSupport.run_load_hooks(:action_dispatch_system_test_case, self)
  end

  SystemTestCase.start_application
end
