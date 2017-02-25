module ActionDispatch
  module SystemTesting
    class Driver # :nodoc:
      def initialize(name)
        @name = name
      end

      def use
        @current = Capybara.current_driver
        Capybara.current_driver = @name
      end

      def reset
        Capybara.current_driver = @current
      end
    end
  end
end
