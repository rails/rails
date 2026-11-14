# frozen_string_literal: true

require "socket"

module ActionDispatch
  module SystemTesting
    class AvailablePortFinder # :nodoc:
      def initialize(host)
        @host = host
      end

      def find
        server = TCPServer.new(@host, 0)
        port = server.addr[1]
        server.close

        # Binding the selected port again verifies it is available for the
        # requested host, including hosts that resolve to multiple interfaces.
        server = TCPServer.new(@host, port)
        port
      rescue Errno::EADDRINUSE
        retry
      ensure
        server&.close
      end
    end
  end
end
