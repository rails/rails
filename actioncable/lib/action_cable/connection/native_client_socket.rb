require "websocket/driver"

module ActionCable
  module Connection
    class NativeClientSocket # :nodoc:
      CONNECTING = 0
      OPEN       = 1
      CLOSING    = 2
      CLOSED     = 3

      attr_reader :env, :url

      def initialize(env, event_target, _, protocols)
        @env = env
        @url = ClientSocket.determine_url(@env)

        @headers = {}

        if protos = env['HTTP_SEC_WEBSOCKET_PROTOCOL']
          protos = protos.split(/ *, */) if String === protos
          if protocol = protos.find { |p| protocols.include?(p) }
            @headers["Sec-Websocket-Protocol"] = protocol
          end
        end

        @nws = env["upgrade.websocket"] = NWSHandler.new(event_target)
      end

      def rack_response
        [ 101, @headers, [] ]
      end

      def transmit(message)
        return false if @nws.ready_state > OPEN
        case message
        when Numeric then @nws.write(message.to_s)
        when String  then @nws.write(message)
          else false
        end
      end

      def close(code = nil, reason = nil)
        @nws.close
      end

      def alive?
        @nws.ready_state == OPEN
      end

      def protocol
        "websocket"
      end

      class NWSHandler
        def initialize(target)
          @ready_state = CONNECTING
          @event_target = target
        end

        attr_reader :ready_state

        # callbacks used by native websocket upgrade support
        def on_open
          return unless @ready_state == CONNECTING
          @ready_state = OPEN

          @event_target.on_open
        end

        def on_message(msg)
          return unless @ready_state == OPEN

          @event_target.on_message(msg)
        end

        def on_close
          return if @ready_state == CLOSED
          @ready_state = CLOSED

          @event_target.on_close(1000, "application closed")
        end
      end
    end
  end
end
