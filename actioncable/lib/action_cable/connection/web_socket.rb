require 'faye/websocket'

module ActionCable
  module Connection
    # Decorate the Faye::WebSocket with helpers we need.
    class WebSocket
      delegate :rack_response, :close, :on, to: :websocket

      def initialize(env)
        @websocket = Faye::WebSocket.websocket?(env) ? Faye::WebSocket.new(env) : nil
      end

      def possible?
        websocket
      end

      def alive?
        websocket && websocket.ready_state == Faye::WebSocket::API::OPEN
      end

      def transmit(data)
        websocket.send data
      end

      protected
        attr_reader :websocket
    end
  end
end
