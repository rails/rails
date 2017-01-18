module ActionCable
  module SubscriptionAdapter
    module ChannelPrefix # :nodoc:
      def broadcast(channel, payload)
        channel = channel_with_prefix(channel)
        super
      end

      def subscribe(channel, callback, success_callback = nil)
        channel = channel_with_prefix(channel)
        super
      end

      def unsubscribe(channel, callback)
        channel = channel_with_prefix(channel)
        super
      end

      private
        # Returns the channel name, including channel_prefix specified in cable.yml
        def channel_with_prefix(channel)
          [@server.config.cable[:channel_prefix], channel].compact.join(":")
        end
    end
  end
end
