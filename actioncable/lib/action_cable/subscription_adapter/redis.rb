gem 'em-hiredis', '~> 0.3.0'
gem 'redis', '~> 3.0'
require 'em-hiredis'
require 'redis'

module ActionCable
  module SubscriptionAdapter
    class Redis < Base # :nodoc:
      # The redis instance used for broadcasting. Not intended for direct user use.
      def broadcast(channel, payload)
        broadcast_redis_connection.publish(channel, payload)
      end

      def subscribe(channel, message_callback, success_callback = nil)
        subscription_redis_connection.pubsub.subscribe(channel, &message_callback).tap do |result|
          result.callback(&success_callback) if success_callback
        end
      end

      def unsubscribe(channel, message_callback)
        hi_redis_conn.pubsub.unsubscribe_proc(channel, message_callback)
      end

      private
        def subscription_redis_connection
          @subscription_redis_connection ||= EM::Hiredis.connect(@server.config.cable[:url]).tap do |redis|
            redis.on(:reconnect_failed) do
              @logger.info "[ActionCable] Redis reconnect failed."
            end
          end
        end

        def broadcast_redis_connection
          @broadcast_redis_connection ||= ::Redis.new(@server.config.cable)
        end
    end
  end
end
