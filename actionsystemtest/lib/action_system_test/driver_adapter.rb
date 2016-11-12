require "action_system_test/driver_adapters"

module ActionSystemTest
  # The <tt>ActionSystemTest::DriverAdapter</tt> module is used to load the driver
  # set in your Rails' test configuration file.
  #
  # The default driver adapter is the +:rails_selenium_driver+.
  module DriverAdapter
    extend ActiveSupport::Concern

    module ClassMethods
      # Returns the current driver that is set. If no driver is set in the
      # Rails' configuration file then +:rails_selenium_driver+ will be
      # initialized.
      def driver
        @driver ||= DriverAdapters.lookup(DEFAULT_DRIVER)
      end

      # Specify the adapter and settings for the system test driver set in the
      # Rails' configuration file.
      def driver=(driver)
        @driver = DriverAdapters.lookup(driver)
        @driver.call
      end
    end
  end
end
