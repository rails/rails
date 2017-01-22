require "rack/handler/puma"

module ActionSystemTest
  class Server # :nodoc:
    def initialize(port)
      @port = port
    end

    def run
      register
      setup
    end

    private
      def register
        Capybara.register_server :puma do |app, host|
          Rack::Handler::Puma.run(app, Port: @port, Threads: "0:1")
        end
      end

      def setup
        set_server
        set_port
      end

      def set_server
        Capybara.server = :puma
      end

      def set_port
        Capybara.server_port = @port
      end
  end
end
