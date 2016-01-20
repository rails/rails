gem 'em-hiredis', '~> 0.3.0'
gem 'redis', '~> 3.0'
require 'em-hiredis'
require 'redis'

module ActionCable
  module SubscriptionAdapter
    class Redis < Base # :nodoc:
      def broadcast(channel, payload)
        redis_connection_for_broadcasts.publish(channel, payload)
      end

      def subscribe(channel, message_callback, success_callback = nil)
        redis_connection_for_subscriptions.pubsub.subscribe(channel, &message_callback).tap do |result|
          result.callback(&success_callback) if success_callback
        end
      end

      def unsubscribe(channel, message_callback)
        hi_redis_conn.pubsub.unsubscribe_proc(channel, message_callback)
      end

      private
        def redis_connection_for_subscriptions
          @redis_connection_for_subscriptions ||= EM::Hiredis.connect(@server.config.cable[:url]).tap do |redis|
            redis.on(:reconnect_failed) do
              @logger.info "[ActionCable] Redis reconnect failed."
            end
          end
        end

        def redis_connection_for_broadcasts
          @redis_connection_for_broadcasts ||= ::Redis.new(@server.config.cable)
        end
    end
  end
end
