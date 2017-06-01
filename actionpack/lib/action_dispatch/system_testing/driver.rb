module ActionDispatch
  module SystemTesting
    class Driver # :nodoc:
      def initialize(name, **options)
        @name = name
        @browser = options[:using]
        @screen_size = options[:screen_size]
        @options = options[:options]
      end

      def use
        register unless rack_test?

        setup
      end

      private
        def rack_test?
          @name == :rack_test
        end

        def register
          Capybara.register_driver @name do |app|
            case @name
            when :selenium then register_selenium(app)
            when :poltergeist then register_poltergeist(app)
            when :webkit then register_webkit(app)
            end
          end
        end

        def register_selenium(app)
          Capybara::Selenium::Driver.new(app, { browser: @browser }.merge(@options)).tap do |driver|
            driver.browser.manage.window.size = Selenium::WebDriver::Dimension.new(*@screen_size)
          end
        end

        def register_poltergeist(app)
          Capybara::Poltergeist::Driver.new(app, @options.merge(window_size: @screen_size))
        end

        def register_webkit(app)
          Capybara::Webkit::Driver.new(app, Capybara::Webkit::Configuration.to_hash.merge(@options)).tap do |driver|
            driver.resize_window(*@screen_size)
          end
        end

        def setup
          Capybara.current_driver = @name
        end
    end
  end
end
