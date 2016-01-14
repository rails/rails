require 'em-hiredis'
require 'redis'

module ActionCable
  module StorageAdapter
    class Redis < Base
      def broadcast(channel, payload)
        redis_conn.publish(channel, payload)
      end

      def subscribe(channel, message_callback, success_callback = nil)
        hi_redis_conn.pubsub.subscribe(channel, &message_callback).tap do |result|
          result.callback(&success_callback) if success_callback
        end
      end

      def unsubscribe(channel, message_callback)
        hi_redis_conn.pubsub.unsubscribe_proc(channel, message_callback)
      end

      private

      # The redis instance used for broadcasting. Not intended for direct user use.
      def redis_conn
        @broadcast ||= ::Redis.new(@server.config.config_opts)
      end

      # The EventMachine Redis instance used by the pubsub adapter.
      def hi_redis_conn
        @redis ||= EM::Hiredis.connect(@server.config.config_opts[:url]).tap do |redis|
          redis.on(:reconnect_failed) do
            @logger.info "[ActionCable] Redis reconnect failed."
            # logger.info "[ActionCable] Redis reconnected. Closing all the open connections."
            # @connections.map &:close
          end
        end
      end
    end
  end
end
