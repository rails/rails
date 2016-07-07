require 'faye/websocket'

module ActionCable
  module Connection
    class FayeClientSocket
      def initialize(env, event_target, stream_event_loop, protocols)
        @env = env
        @event_target = event_target
        @protocols = protocols

        @faye = nil
      end

      def alive?
        @faye && @faye.ready_state == Faye::WebSocket::API::OPEN
      end

      def transmit(data)
        connect
        @faye.send data
      end

      def close
        @faye && @faye.close
      end

      def protocol
        @faye && @faye.protocol
      end

      def rack_response
        connect
        @faye.rack_response
      end

      private
        def connect
          return if @faye
          @faye = Faye::WebSocket.new(@env, @protocols)

          @faye.on(:open)    { |event| @event_target.on_open }
          @faye.on(:message) { |event| @event_target.on_message(event.data) }
          @faye.on(:close)   { |event| @event_target.on_close(event.reason, event.code) }
          @faye.on(:error)   { |event| @event_target.on_error(event.message) }
        end
    end
  end
end
