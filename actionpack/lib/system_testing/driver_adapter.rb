require 'system_testing/driver_adapters'

module SystemTesting
  module DriverAdapter
    extend ActiveSupport::Concern

    module ClassMethods
      def default_driver
        :capybara_rack_test_driver
      end

      def driver
        @driver ||= DriverAdapters.lookup(default_driver).new
      end

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
