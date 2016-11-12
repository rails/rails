require "action_system_test/driver_adapters"

module ActionSystemTest
  # The <tt>ActionSystemTest::DriverAdapter</tt> module is used to load the driver
  # set in the +system_test_helper+ file generated with your application.
  #
  # The default driver adapter is the +:rails_selenium_driver+.
  module DriverAdapter
    extend ActiveSupport::Concern

    module ClassMethods
      # Returns the current driver that is set in the <tt>ActionSystemTestCase</tt>
      # class generated with your Rails application. If no driver is set
      # +:rails_selenium_driver+ will be initialized.
      def driver
        @driver ||= DriverAdapters.lookup(DEFAULT_DRIVER)
      end

      # Specify the adapter and settings for the system test driver set in the
      # Rails' configuration file.
      #
      # When set, the driver will be initialized.
      def driver=(driver)
        @driver = DriverAdapters.lookup(driver)
        @driver.call
      end
    end
  end
end
