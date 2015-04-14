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
      redis.publish channel, message.to_json
      logger.info "[ActionCable] Broadcasting to channel (#{channel}): #{message}"
    end

  end
end
