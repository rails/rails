# frozen_string_literal: true

module ActionCable
  module SubscriptionAdapter
    class Base
      attr_reader :logger, :server

      def initialize(server)
        @server = server
        @logger = @server.logger
      end

      def broadcast(_channel, _payload)
        raise NotImplementedError
      end

      def subscribe(_channel, _message_callback, _success_callback = nil)
        raise NotImplementedError
      end

      def unsubscribe(_channel, _message_callback)
        raise NotImplementedError
      end

      def shutdown
        raise NotImplementedError
      end
    end
  end
end
