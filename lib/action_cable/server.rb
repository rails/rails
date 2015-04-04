module ActionCable
  class Server
    cattr_accessor(:logger, instance_reader: true) { Rails.logger }

    attr_accessor :registered_channels, :worker_pool

    def initialize(redis_config:, channels:, worker_pool_size: 100, connection: Connection)
      @redis_config = redis_config
      @registered_channels = Set.new(channels)
      @worker_pool = ActionCable::Worker.pool(size: worker_pool_size)
      @connection_class = connection
    end

    def call(env)
      @connection_class.new(self, env).process
    end

    def pubsub
      @pubsub ||= EM::Hiredis.connect(@redis_config['url']).pubsub
    end

  end
end
