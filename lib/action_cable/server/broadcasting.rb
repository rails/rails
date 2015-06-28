module ActionCable
  module Server
    module Broadcasting
      def broadcast(channel, message)
        broadcaster_for(channel).broadcast(message)
      end

      def broadcaster_for(channel)
        Broadcaster.new(self, channel)
      end

      def broadcasting_redis
        @broadcasting_redis ||= Redis.new(redis_config)
      end      

      private
        class Broadcaster
          attr_reader :server, :channel

          def initialize(server, channel)
            @server, @channel = server, channel
          end

          def broadcast(message)
            server.logger.info "[ActionCable] Broadcasting to #{channel}: #{message}"
            broadcast_without_logging(message)
          end

          def broadcast_without_logging(message)            
            server.broadcasting_redis.publish channel, message.to_json
          end
        end
    end
  end
end