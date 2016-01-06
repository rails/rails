module ActionCable
  module StorageAdapter
    class Base
      attr_reader :logger, :server

      def initialize(server)
        @server = server
        @logger = @server.logger
      end

      # Storage connection instance used for broadcasting. Not intended for direct user use.
      def broadcast
        raise NotImplementedError
      end

      # Storage connection instance used for pubsub.
      def pubsub
        raise NotImplementedError
      end
    end
  end
end
