require "rack/handler/puma"

module ActionDispatch
  module SystemTesting
    class Server # :nodoc:
      def run
        register
        setup
      end

      private
        def register
          Capybara.register_server :rails_puma do |app, port, host|
            Rack::Handler::Puma.run(app, Port: port, Threads: "0:1")
          end
        end

        def setup
          Capybara.server = :rails_puma
        end
    end
  end
end
