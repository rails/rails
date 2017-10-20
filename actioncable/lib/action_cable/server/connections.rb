# frozen_string_literal: true

module ActionCable
  module Server
    # Collection class for all the connections that have been established on this specific server. Remember, usually you'll run many Action Cable servers, so
    # you can't use this collection as a full list of all of the connections established against your application. Instead, use RemoteConnections for that.
    module Connections # :nodoc:
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
      # then can't rely on being able to communicate with the connection. To solve this, a 3 second heartbeat runs on all connections. If the beat fails, we automatically
      # disconnect.
      def setup_heartbeat_timer
        @heartbeat_timer ||= event_loop.timer(BEAT_INTERVAL) do
          event_loop.post { connections.map(&:beat) }
        end
      end

      def open_connections_statistics
        connections.map(&:statistics)
      end
    end
  end
end
