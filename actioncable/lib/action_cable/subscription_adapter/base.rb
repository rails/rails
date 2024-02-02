# frozen_string_literal: true

# :markup: markdown

module ActionCable
  module SubscriptionAdapter
    class Base
      private attr_reader :executor
      private attr_reader :config

      def initialize(server)
        @executor = server.executor
        @config = server.config
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

      def identifier
        config.cable[:id] ||= "ActionCable-PID-#{$$}"
      end
    end
  end
end
