module ActionDispatch
  module SystemTesting
    class Driver # :nodoc:
      def initialize(name)
        @name = name
      end

      def run
        register
      end

      private
        def register
          Capybara.default_driver = @name
        end
    end
  end
end
