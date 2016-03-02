require 'websocket/driver'

module ActionCable
  module Connection
    # Wrap the real socket to minimize the externally-presented API
    class WebSocket
      def initialize(env, event_target, event_loop, client_socket_class)
        @websocket = ::WebSocket::Driver.websocket?(env) ? client_socket_class.new(env, event_target, event_loop) : nil
      end

      def possible?
        websocket
      end

      def alive?
        websocket && websocket.alive?
      end

      def transmit(data)
        websocket.transmit data
      end

      def close
        websocket.close
      end

      def rack_response
        websocket.rack_response
      end

      protected
        attr_reader :websocket
    end
  end
end
