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

      def driver=(adapter: default_driver, settings: {})
        @driver = DriverAdapters.lookup(adapter).new(settings)
      end
    end
  end
end
