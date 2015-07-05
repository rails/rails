module ActionCable
  module Server
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