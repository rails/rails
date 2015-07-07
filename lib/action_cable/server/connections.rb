module ActionCable
  module Server
    # Collection class for all the connections that's been established on this specific server. Remember, usually you'll run many cable servers, so
    # you can't use this collection as an full list of all the connections established against your application. Use RemoteConnections for that.
    # As such, this is primarily for internal use.
    module Connections
      def connections
        @connections ||= []
      end

      def add_connection(connection)
        connections << connection
      end

      def remove_connection(connection)
        connections.delete connection
      end

      def open_connections_statistics
        connections.map(&:statistics)
      end
    end
  end
end