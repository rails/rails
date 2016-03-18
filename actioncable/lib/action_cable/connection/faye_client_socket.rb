require 'faye/websocket'

module ActionCable
  module Connection
    class FayeClientSocket
      def initialize(env, event_target, stream_event_loop)
        @env = env
        @event_target = event_target

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

      def rack_response
        connect
        @faye.rack_response
      end

      private
        def connect
          return if @faye
          @faye = Faye::WebSocket.new(@env)

          @faye.on(:open)    { |event| @event_target.on_open }
          @faye.on(:message) { |event| @event_target.on_message(event.data) }
          @faye.on(:close)   { |event| @event_target.on_close(event.reason, event.code) }
        end
    end
  end
end
