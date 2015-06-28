module ActionCable
  module Server
    module Broadcasting
      def broadcaster_for(channel)
        Broadcaster.new(self, channel)
      end

      def broadcast(channel, message)
        broadcaster_for(channel).broadcast(message)
      end

      class Broadcaster
        attr_reader :server, :channel, :redis
        delegate :logger, to: :server

        def initialize(server, channel)
          @server, @channel = server, channel
          @redis = @server.threaded_redis
        end

        def broadcast(message)
          logger.info "[ActionCable] Broadcasting to #{channel}: #{message}"
          redis.publish channel, message.to_json
        end
      end
    end
  end
end