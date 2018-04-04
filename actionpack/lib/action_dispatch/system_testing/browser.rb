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

      def driver_option
        @option ||= case type
                    when :chrome
                      Selenium::WebDriver::Chrome::Options.new
                    when :firefox
                      Selenium::WebDriver::Firefox::Options.new
        end
      end

      private
        def headless_chrome_browser_options
          driver_option.args << "--headless"
          driver_option.args << "--disable-gpu" if Gem.win_platform?

          driver_option
        end

        def headless_firefox_browser_options
          driver_option.args << "-headless"

          driver_option
        end
    end
  end
end
