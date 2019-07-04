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
