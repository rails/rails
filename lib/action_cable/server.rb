module ActionCable
  class Server
    cattr_accessor(:logger, instance_reader: true) { Rails.logger }

    attr_accessor :registered_channels, :redis_config

    def initialize(redis_config:, channels:, worker_pool_size: 100, connection: Connection)
      @redis_config = redis_config.with_indifferent_access
      @registered_channels = Set.new(channels)
      @worker_pool_size = worker_pool_size
      @connection_class = connection

      logger.info "[ActionCable] Initialized server (redis_config: #{@redis_config.inspect}, worker_pool_size: #{@worker_pool_size})"
    end

    def call(env)
      @connection_class.new(self, env).process
    end

    def worker_pool
      @worker_pool ||= ActionCable::Worker.pool(size: @worker_pool_size)
    end

    def pubsub
      @pubsub ||= EM::Hiredis.connect(@redis_config[:url]).pubsub
    end

    def remote_connections
      @remote_connections ||= RemoteConnections.new(self)
    end

    def connection_identifiers
      @connection_class.identifiers
    end

  end
end
