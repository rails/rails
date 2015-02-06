module ActionCable
  module Channel

    module Redis
      extend ActiveSupport::Concern

      included do
        on_unsubscribe :unsubscribe_from_redis_channels
      end

      def subscribe_to(redis_channel, callback = nil)
        @_redis_channels ||= []

        callback ||= -> (message) { broadcast ActiveSupport::JSON.decode(message) }
        @_redis_channels << [ redis_channel, callback ]

        pubsub.subscribe(redis_channel, &callback)
      end

      protected
        def unsubscribe_from_redis_channels
          if @_redis_channels
            @_redis_channels.each { |channel, callback| pubsub.unsubscribe_proc(channel, callback) }
          end
        end

        def pubsub
          @connection.pubsub
        end
    end

  end
end