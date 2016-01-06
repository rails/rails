require 'em-hiredis'
require 'redis'

module ActionCable
  module StorageAdapter
    class Redis < Base
      # The redis instance used for broadcasting. Not intended for direct user use.
      def broadcast
        @broadcast ||= ::Redis.new(@server.config.config_opts)
      end

      def pubsub
        redis.pubsub
      end

      private

      # The EventMachine Redis instance used by the pubsub adapter.
      def redis
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
