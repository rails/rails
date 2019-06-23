# frozen_string_literal: true

require "active_support/core_ext/module/redefine_method"

module ActionCable
  # If you need to disconnect a given connection, you can go through the
  # RemoteConnections. You can find the connections you're looking for by
  # searching for the identifier declared on the connection. For example:
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
  # This will disconnect all the connections established for
  # <tt>User.find(1)</tt>, across all servers running on all machines, because
  # it uses the internal channel that all of these servers are subscribed to.
  #
  # You can also use the remote connection to forcibly unsubscribe a connection
  # from a specific stream. For example:
  #
  #   subscription_identifier = "{\"channel\":\"ChatChannel\", \"chat_id\":1}"
  #   ActionCable.server.remote_connections.where(current_user: User.find(1)).unsubscribe(subscription_identifier)
  class RemoteConnections
    attr_reader :server

    def initialize(server)
      @server = server
    end

    def where(identifier)
      RemoteConnection.new(server, identifier)
    end

    private
      # Represents a single remote connection found via <tt>ActionCable.server.remote_connections.where(*)</tt>.
      # Exists for the purpose of calling #disconnect or #unsubscribe on that connection.
      class RemoteConnection
        class InvalidIdentifiersError < StandardError; end

        include Connection::Identification, Connection::InternalChannel

        def initialize(server, ids)
          @server = server
          set_identifier_instance_vars(ids)
        end

        # Uses the internal channel to unsubscribe a connection from a given channel
        def unsubscribe(channel_identifier)
          server.broadcast internal_channel, type: "unsubscribe", channel_identifier: channel_identifier
        end

        # Uses the internal channel to disconnect the connection.
        def disconnect
          server.broadcast internal_channel, type: "disconnect"
        end

        # Returns all the identifiers that were applied to this connection.
        redefine_method :identifiers do
          server.connection_identifiers
        end

        protected
          attr_reader :server

        private
          def set_identifier_instance_vars(ids)
            raise InvalidIdentifiersError unless valid_identifiers?(ids)
            ids.each { |k, v| instance_variable_set("@#{k}", v) }
          end

          def valid_identifiers?(ids)
            keys = ids.keys
            identifiers.all? { |id| keys.include?(id) }
          end
      end
  end
end
