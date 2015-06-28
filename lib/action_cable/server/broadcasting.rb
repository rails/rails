module ActionCable
  module Server
    module Broadcasting
      def broadcast(channel, message)
        broadcaster_for(channel).broadcast(message)
      end

      def broadcaster_for(channel)
        Broadcaster.new(self, channel)
      end

      private
        def redis_for_threads
          @redis_for_threads ||= Redis.new(redis_config)
        end      

        class Broadcaster
          def initialize(server, channel)
            @server, @channel = server, channel
          end

          def broadcast(message)
            server.logger.info "[ActionCable] Broadcasting to #{channel}: #{message}"
            broadcast_without_logging(message)
          end

          def broadcast_without_logging(message)            
            server.redis_for_threads.publish channel, message.to_json
          end

          private
            attr_reader :server, :channel
        end
    end
  end
end