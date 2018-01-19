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

      private
        def headless_chrome_browser_options
          options = Selenium::WebDriver::Chrome::Options.new
          options.args << "--headless"
          options.args << "--disable-gpu"

          options
        end

        def headless_firefox_browser_options
          options = Selenium::WebDriver::Firefox::Options.new
          options.args << "-headless"

          options
        end
    end
  end
end
