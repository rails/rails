module ActionCable
  module Server
    # Collection class for all the connections that's been established on this specific server. Remember, usually you'll run many cable servers, so
    # you can't use this collection as an full list of all the connections established against your application. Use RemoteConnections for that.
    # As such, this is primarily for internal use.
    module Connections
      BEAT_INTERVAL = 3

      def connections
        @connections ||= []
      end

      def add_connection(connection)
        connections << connection
      end

      def remove_connection(connection)
        connections.delete connection
      end

      # WebSocket connection implementations differ on when they'll mark a connection as stale. We basically never want a connection to go stale, as you
      # then can't rely on being able to receive and send to it. So there's a 3 second heartbeat running on all connections. If the beat fails, we automatically
      # disconnect.
      def setup_heartbeat_timer
        EM.next_tick do
          @heartbeat_timer ||= EventMachine.add_periodic_timer(BEAT_INTERVAL) do
            EM.next_tick { connections.map(&:beat) }
          end
        end
      end

      def open_connections_statistics
        connections.map(&:statistics)
      end
    end
  end
end
