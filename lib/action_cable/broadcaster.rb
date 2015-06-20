module ActionCable
  class Broadcaster
    attr_reader :server, :channel, :redis
    delegate :logger, to: :server

    def initialize(server, channel)
      @server = server
      @channel = channel
      @redis = @server.threaded_redis
    end

    def broadcast(message)
      logger.info "[ActionCable] Broadcasting to #{channel}: #{message}"
      redis.publish channel, message.to_json
    end
  end
end
