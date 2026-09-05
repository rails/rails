# frozen_string_literal: true

# :markup: markdown

module ActionCable
  module Server
    # # Action Cable Server Connections
    #
    # Collection class for all the connections that have been established on this
    # specific server. Remember, usually you'll run many Action Cable servers, so
    # you can't use this collection as a full list of all of the connections
    # established against your application. Instead, use RemoteConnections for that.
    module Connections # :nodoc:
      def connections = connections_map.values

      def each_connection(...)
        # Iterate a snapshot: the heartbeat, #restart and statistics all walk the
        # live connections while worker threads concurrently add/remove entries,
        # and mutating a Hash mid-iteration raises a RuntimeError.
        connections.each(...)
      end

      def add_connection(connection)
        connections_map[connection.object_id] = connection
      end

      def remove_connection(connection)
        connections_map.delete connection.object_id
      end

      def open_connections_statistics
        each_connection.map(&:statistics)
      end

      private
        def connections_map
          @connections_map ||= {}
        end
    end
  end
end
