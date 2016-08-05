require 'system_testing/driver_adapters'

module SystemTesting
  module DriverAdapter
    extend ActiveSupport::Concern

    included do
      self.driver_adapter = :capybara_rack_test_driver
    end

    module ClassMethods
      def driver_adapter=(driver_name_or_class)
        driver = DriverAdapters.lookup(driver_name_or_class).new
        driver.call
      end
    end
  end
end
