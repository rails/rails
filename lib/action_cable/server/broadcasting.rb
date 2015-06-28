module ActionCable
  module Server
    module Broadcasting
      def broadcast(broadcasting, message)
        broadcaster_for(broadcasting).broadcast(message)
      end

      def broadcaster_for(broadcasting)
        Broadcaster.new(self, broadcasting)
      end

      def broadcasting_redis
        @broadcasting_redis ||= Redis.new(redis_config)
      end      

      private
        class Broadcaster
          attr_reader :server, :broadcasting

          def initialize(server, broadcasting)
            @server, @broadcasting = server, broadcasting
          end

          def broadcast(message)
            server.logger.info "[ActionCable] Broadcasting to #{broadcasting}: #{message}"
            broadcast_without_logging(message)
          end

          def broadcast_without_logging(message)            
            server.broadcasting_redis.publish broadcasting, message.to_json
          end
        end
    end
  end
end