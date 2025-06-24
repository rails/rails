# frozen_string_literal: true

# :markup: markdown

module ActionDispatch
  module SystemTesting
    class Browser # :nodoc:
      attr_reader :name

      def initialize(name)
        @name = name
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
            default_chrome_options
          when :firefox
            default_firefox_options
          end
      end

      def configure
        yield options if block_given?
      end

      # driver_path is lazily initialized by default. Eagerly set it to avoid race
      # conditions when using parallel tests.
      def preload
        case type
        when :chrome
          resolve_driver_path(::Selenium::WebDriver::Chrome)
        when :firefox
          resolve_driver_path(::Selenium::WebDriver::Firefox)
        end
      end

      private
        def default_chrome_options
          options = ::Selenium::WebDriver::Chrome::Options.new
          options.add_argument("--disable-search-engine-choice-screen")
          options.add_argument("--headless") if name == :headless_chrome
          options.add_argument("--disable-gpu") if Gem.win_platform?
          options
        end

        def default_firefox_options
          options = ::Selenium::WebDriver::Firefox::Options.new
          options.add_argument("-headless") if name == :headless_firefox
          options
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
