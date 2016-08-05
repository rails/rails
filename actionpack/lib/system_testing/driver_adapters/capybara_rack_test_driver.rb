module SystemTesting
  module DriverAdapters
    class CapybaraRackTestDriver
      attr_reader :useragent

      def initialize(useragent: 'Capybara')
        @useragent = useragent
      end

      def call
        registration
      end

      private
        def registration
          Capybara.register_driver :rack_test do |app|
            Capybara::RackTest::Driver.new(app, headers: {
              'HTTP_USER_AGENT' => @useragent
            })
          end
        end
    end
  end
end
