module SystemTesting
  module DriverAdapters
    extend ActiveSupport::Autoload

    autoload :CapybaraRackTestDriver
    autoload :CapybaraSeleniumDriver

    class << self
      def lookup(name)
        const_get(name.to_s.camelize)
      end
    end
  end
end
