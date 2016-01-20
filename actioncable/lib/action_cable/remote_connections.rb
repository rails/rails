module ActionCable
  # If you need to disconnect a given connection, you go through the RemoteConnections. You find the connections you're looking for by
  # searching the identifier declared on the connection. Example:
  #
  #   module ApplicationCable
  #     class Connection < ActionCable::Connection::Base
  #       identified_by :current_user
  #       ....
  #     end
  #   end
  #
  #   ActionCable.server.remote_connections.where(current_user: User.find(1)).disconnect
  #
  # That will disconnect all the connections established for User.find(1) across all servers running on all machines (because it uses
  # the internal channel that all these servers are subscribed to).
  class RemoteConnections
    attr_reader :server

    def initialize(server)
      @server = server
    end

    def where(identifier)
      RemoteConnection.new(server, identifier)
    end

    private
      # Represents a single remote connection found via ActionCable.server.remote_connections.where(*).
      # Exists for the solely for the purpose of calling #disconnect on that connection.
      class RemoteConnection
        class InvalidIdentifiersError < StandardError; end

        include Connection::Identification, Connection::InternalChannel

        def initialize(server, ids)
          @server = server
          set_identifier_instance_vars(ids)
        end

        # Uses the internal channel to disconnect the connection.
        def disconnect
          server.broadcast internal_channel, type: 'disconnect'
        end

        # Returns all the identifiers that were applied to this connection.
        def identifiers
          server.connection_identifiers
        end

        private
          attr_reader :server

          def set_identifier_instance_vars(ids)
            raise InvalidIdentifiersError unless valid_identifiers?(ids)
            ids.each { |k,v| instance_variable_set("@#{k}", v) }
          end

          def valid_identifiers?(ids)
            keys = ids.keys
            identifiers.all? { |id| keys.include?(id) }
          end
      end
  end
end
