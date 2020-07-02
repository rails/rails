# frozen_string_literal: true

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
        case name
        when :headless_chrome
          headless_chrome_browser_options
        when :headless_firefox
          headless_firefox_browser_options
        else
          capabilities
        end
      end

      def capabilities
        @option ||=
          case type
          when :chrome
            ::Selenium::WebDriver::Chrome::Options.new
          when :firefox
            ::Selenium::WebDriver::Firefox::Options.new
          end
      end

      # driver_path can be configured as a proc. The webdrivers gem uses this
      # proc to update web drivers. Running this proc early allows us to only
      # update the webdriver once and avoid race conditions when using
      # parallel tests.
      def preload
        case type
        when :chrome
          if ::Selenium::WebDriver::Service.respond_to? :driver_path=
            ::Selenium::WebDriver::Chrome::Service.driver_path.try(:call)
          else
            # Selenium <= v3.141.0
            ::Selenium::WebDriver::Chrome.driver_path
          end
        when :firefox
          if ::Selenium::WebDriver::Service.respond_to? :driver_path=
            ::Selenium::WebDriver::Firefox::Service.driver_path.try(:call)
          else
            # Selenium <= v3.141.0
            ::Selenium::WebDriver::Firefox.driver_path
          end
        end
      end

      private
        def headless_chrome_browser_options
          capabilities.args << "--headless"
          capabilities.args << "--disable-gpu" if Gem.win_platform?

          capabilities
        end
        
        def headless_firefox_browser_options
          capabilities.args << "-headless"

          capabilities
        end
    end
  end
end
