# frozen_string_literal: true

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
          Capybara.server = :puma, { Silent: self.class.silence_puma, Threads: '0:1' } if Capybara.server == Capybara.servers[:default]
        end

        def set_port
          Capybara.always_include_port = true
        end
    end
  end
end
