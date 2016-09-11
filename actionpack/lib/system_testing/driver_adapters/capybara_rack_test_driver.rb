module SystemTesting
  module DriverAdapters
    # == CapybaraRackTestDriver for System Testing
    #
    # This is the default driver for Capybara. This driver does not support
    # JavaScript because it doesn't open a browser when running the test suite.
    #
    # Although it does not support JavaScript testing the
    # <tt>CapybaraRackTestDriver</tt> is fast and efficient. This driver requires
    # no setup and becasue it does not need a webserver, additional configuration
    # is not required.
    #
    # The <tt>CapybaraRackTestDriver</tt> only takes one argument for initialization
    # which is +:useragent+.
    #
    # To set the useragent add the following to your
    # Rails' configuration file:
    #
    #   config.system_testing.driver = SystemTesting::DriverAdapters::CapybaraRackTestDriver.new(
    #     useragent: 'My UserAgent'
    #   )
    class CapybaraRackTestDriver
      attr_reader :useragent

      def initialize(useragent: 'Capybara') # :nodoc:
        @useragent = useragent
      end

      def call # :nodoc:
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
