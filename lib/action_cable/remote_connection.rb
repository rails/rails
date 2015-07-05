module ActionCable
  class RemoteConnection
    class InvalidIdentifiersError < StandardError; end

    include Connection::Identification, Connection::InternalChannel

    def initialize(server, ids)
      @server = server
      set_identifier_instance_vars(ids)
    end

    def disconnect
      server.broadcast internal_redis_channel, type: 'disconnect'
    end

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
