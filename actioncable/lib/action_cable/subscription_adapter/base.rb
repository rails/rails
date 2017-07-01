module ActionCable
  module SubscriptionAdapter
    class Base
      attr_reader :logger, :server

      def initialize(server)
        @server = server
        @logger = @server.logger
      end

      def broadcast(channel, payload)
        raise NotImplementedError
      end

      def subscribe(channel, message_callback, success_callback = nil)
        raise NotImplementedError
      end

      def unsubscribe(channel, message_callback)
        raise NotImplementedError
      end

      def shutdown
        raise NotImplementedError
      end
    end
  end
end
