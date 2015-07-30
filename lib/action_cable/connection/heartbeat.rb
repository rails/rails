module ActionCable
  module Connection
    # Websocket connection implementations differ on when they'll mark a connection as stale. We basically never want a connection to go stale, as you
    # then can't rely on being able to receive and send to it. So there's a 3 second heartbeat running on all connections. If the beat fails, we automatically
    # disconnect.
    class Heartbeat
      BEAT_INTERVAL = 3

      def initialize(connection)
        @connection = connection
      end

      def start
        beat
        @timer = EventMachine.add_periodic_timer(BEAT_INTERVAL) { beat }
      end

      def stop
        EventMachine.cancel_timer(@timer) if @timer
      end

      private
        attr_reader :connection

        def beat
          connection.transmit({ identifier: '_ping', message: Time.now.to_i }.to_json)
        end
    end
  end
end
