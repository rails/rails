module ActionDispatch
  module SystemTesting
    class Server # :nodoc:
      class << self
        attr_accessor :silence_puma
      end

      self.silence_puma = false

      def run
        setup
      end

      private
        def setup
          set_server
          set_port
        end

        def set_server
          Capybara.server = :puma, { Silent: self.class.silence_puma }
        end

        def set_port
          Capybara.always_include_port = true
        end
    end
  end
end
