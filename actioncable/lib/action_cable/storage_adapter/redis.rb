begin
  require 'em-hiredis'
  require 'redis'
rescue Gem::LoadError => e
  raise Gem::LoadError, "You are trying to use the Redis ActionCable adapter, but do not have the proper gems installed. Add `gem 'em-hiredis'` and `gem 'redis'` to your Gemfile (and ensure its version is at the minimum required by ActionCable)."
end

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
        @hi_redis_conn ||= EM::Hiredis.connect(@server.config.cable[:url]).tap do |redis|
          redis.on(:reconnect_failed) do
            @logger.info "[ActionCable] Redis reconnect failed."
          end
        end
      end
      def redis_conn
        @redis_conn ||= ::Redis.new(@server.config.cable)
      end
    end
  end
end
