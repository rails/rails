# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    class Browser # :nodoc:
      attr_reader :name

      def initialize(name)
        @name = name
        set_default_options
      end

      def type
        case name
        when :headless_chrome
          :chrome
        when :headless_firefox
          :firefox
        else
          name
        end
      end

      def options
        @options ||=
          case type
          when :chrome
            ::Selenium::WebDriver::Chrome::Options.new
          when :firefox
            ::Selenium::WebDriver::Firefox::Options.new
          end
      end

      def configure
        yield options if block_given?
      end

      # driver_path is lazily initialized by default. Eagerly set it to
      # avoid race conditions when using parallel tests.
      def preload
        case type
        when :chrome
          resolve_driver_path(::Selenium::WebDriver::Chrome)
        when :firefox
          resolve_driver_path(::Selenium::WebDriver::Firefox)
        end
      end

      private
        def set_default_options
          case name
          when :headless_chrome
            set_headless_chrome_browser_options
          when :headless_firefox
            set_headless_firefox_browser_options
          end
        end

        def set_headless_chrome_browser_options
          configure do |capabilities|
            capabilities.add_argument("--headless")
            capabilities.add_argument("--disable-gpu") if Gem.win_platform?
          end
        end

        def set_headless_firefox_browser_options
          configure do |capabilities|
            capabilities.add_argument("-headless")
          end
        end

        def resolve_driver_path(namespace)
          # The path method has been deprecated in 4.20.0
          if Gem::Version.new(::Selenium::WebDriver::VERSION) >= Gem::Version.new("4.20.0")
            namespace::Service.driver_path = ::Selenium::WebDriver::DriverFinder.new(options, namespace::Service.new).driver_path
          else
            namespace::Service.driver_path = ::Selenium::WebDriver::DriverFinder.path(options, namespace::Service)
          end
        end
    end
  end
end
