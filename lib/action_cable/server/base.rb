module ActionCable
  module Server
    class Base
      include ActionCable::Server::Broadcasting

      cattr_accessor(:logger, instance_reader: true) { Rails.logger }

      attr_accessor :registered_channels, :redis_config, :log_tags

      def initialize(redis_config:, channels:, worker_pool_size: 100, connection: Connection, log_tags: [ 'ActionCable' ])
        @redis_config = redis_config.with_indifferent_access
        @registered_channels = Set.new(channels)
        @worker_pool_size = worker_pool_size
        @connection_class = connection
        @log_tags = log_tags

        @connections = []

        logger.info "[ActionCable] Initialized server (redis_config: #{@redis_config.inspect}, worker_pool_size: #{@worker_pool_size})"
      end

      def call(env)
        @connection_class.new(self, env).process
      end

      def worker_pool
        @worker_pool ||= ActionCable::Server::Worker.pool(size: @worker_pool_size)
      end

      def pubsub
        @pubsub ||= redis.pubsub
      end

      def redis
        @redis ||= begin
          redis = EM::Hiredis.connect(@redis_config[:url])
          redis.on(:reconnect_failed) do
            logger.info "[ActionCable] Redis reconnect failed."
            # logger.info "[ActionCable] Redis reconnected. Closing all the open connections."
            # @connections.map &:close
          end
          redis
        end
      end

      def threaded_redis
        @threaded_redis ||= Redis.new(redis_config)
      end

      def remote_connections
        @remote_connections ||= RemoteConnections.new(self)
      end

      def connection_identifiers
        @connection_class.identifiers
      end

      def add_connection(connection)
        @connections << connection
      end

      def remove_connection(connection)
        @connections.delete connection
      end

      def open_connections_statistics
        @connections.map(&:statistics)
      end
    end
  end
end