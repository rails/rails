require 'system_testing/driver_adapters'

module SystemTesting
  # The <tt>SystemTesting::DriverAdapter</tt> module is used to load the driver
  # set in your Rails' test configuration file.
  #
  # The default driver adapter is the +:rails_selenium_driver+.
  module DriverAdapter
    extend ActiveSupport::Concern

    module ClassMethods
      def default_driver # :nodoc
        :rails_selenium_driver
      end

      # Returns the current driver that is set. If no driver is set in the
      # Rails' configuration file then +:rails_selenium_driver+ will be
      # initialized.
      def driver
        @driver ||= DriverAdapters.lookup(default_driver)
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
