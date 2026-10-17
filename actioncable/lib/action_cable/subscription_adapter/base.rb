# frozen_string_literal: true

# :markup: markdown

module ActionCable
  module SubscriptionAdapter
    class Base
      delegate :logger, to: :config

      def initialize(server)
        @executor = server.executor
        @config = server.config
      end

      def broadcast(channel, payload)
        raise NotImplementedError
      end

      # Broadcasts each `[channel, payload]` pair of `broadcasts`, in order. This is
      # how ActionCable::Server::Broadcasting#batch_broadcasts hands over a batch; the
      # default sends them one at a time, and adapters that can send several messages
      # in one go override it.
      def broadcast_batch(broadcasts)
        broadcasts.each { |channel, payload| broadcast(channel, payload) }
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
        config.cable[:id] = "ActionCable-PID-#{$$}" unless config.cable.key?(:id)
        config.cable[:id]
      end

      private
        attr_reader :executor, :config
    end
  end
end
