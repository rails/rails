require 'system_testing/driver_adapters'

module SystemTesting
  # The <tt>SystemTesting::DriverAdapter</tt> module is used to load the driver
  # set in your Rails' test configuration file.
  #
  # The default driver adapters is the +:capybara_rack_test_driver+.
  module DriverAdapter
    extend ActiveSupport::Concern

    module ClassMethods
      def default_driver # :nodoc
        :capybara_rack_test_driver
      end

      # Returns the current driver that is set. If no driver is set in the
      # Rails' configuration file then +:capybara_rack_test_driver+ will be
      # initialized.
      def driver
        @driver ||= DriverAdapters.lookup(default_driver).new
      end

      # Specify the adapter and settings for the system test driver set in the
      # Rails' configuration file.
      def driver=(adapter)
        @driver = case adapter
        when Symbol
          DriverAdapters.lookup(adapter).new
        else
          adapter
        end

        @driver.call
      end
    end
  end
end
