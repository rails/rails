# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    class Browser # :nodoc:
      attr_reader :name, :options

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

      def configure
        initialize_options
        yield options if block_given? && options
      end

      # driver_path can be configured as a proc. The webdrivers gem uses this
      # proc to update web drivers. Running this proc early allows us to only
      # update the webdriver once and avoid race conditions when using
      # parallel tests.
      def preload
        case type
        when :chrome
          if ::Selenium::WebDriver::Service.respond_to? :driver_path=
            ::Selenium::WebDriver::Chrome::Service.driver_path&.call
          else
            # Selenium <= v3.141.0
            ::Selenium::WebDriver::Chrome.driver_path
          end
        when :firefox
          if ::Selenium::WebDriver::Service.respond_to? :driver_path=
            ::Selenium::WebDriver::Firefox::Service.driver_path&.call
          else
            # Selenium <= v3.141.0
            ::Selenium::WebDriver::Firefox.driver_path
          end
        end
      end

      private
        def initialize_options
          @options ||=
            case type
            when :chrome
              ::Selenium::WebDriver::Chrome::Options.new
            when :firefox
              ::Selenium::WebDriver::Firefox::Options.new
            end
        end

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
    end
  end
end
