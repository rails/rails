require 'system_testing/driver_adapters'

module SystemTesting
  module DriverAdapter
    extend ActiveSupport::Concern

    module ClassMethods
      attr_accessor :driver_adapter

      def driver_adapter=(driver_name_or_class)
        driver = DriverAdapters.lookup(driver_name_or_class).new
        driver.call
      end
    end
  end
end
