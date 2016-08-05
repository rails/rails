module SystemTesting
  module DriverAdapters
    extend ActiveSupport::Autoload

    autoload :CapybaraRackTestDriver

    class << self
      def lookup(name)
        const_get(name.to_s.camelize)
      end
    end
  end
end
