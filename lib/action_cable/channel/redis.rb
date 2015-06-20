module ActionCable
  module Channel
    module Redis
      extend ActiveSupport::Concern

      included do
        on_unsubscribe :unsubscribe_from_all_channels
        delegate :pubsub, to: :connection
      end

      def subscribe_to(redis_channel, callback = nil)
        callback ||= default_subscription_callback(redis_channel)
        @_redis_channels ||= []
        @_redis_channels << [ redis_channel, callback ]

        pubsub.subscribe(redis_channel, &callback)
        logger.info "#{channel_name} subscribed to broadcasts from #{redis_channel}"
      end

      def unsubscribe_from_all_channels
        if @_redis_channels
          @_redis_channels.each do |redis_channel, callback|
            pubsub.unsubscribe_proc(redis_channel, callback)
            logger.info "#{channel_name} unsubscribed to broadcasts from #{redis_channel}"
          end
        end
      end

      protected
        def default_subscription_callback(channel)
          -> (message) do
            transmit ActiveSupport::JSON.decode(message), via: "broadcast from #{channel}"
          end
        end
    end
  end
end
