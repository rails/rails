module ActionCable
  module Server
    class Base
      include ActionCable::Server::Broadcasting
      include ActionCable::Server::Connections

      cattr_accessor(:config, instance_accessor: true) { ActionCable::Server::Configuration.new }
      
      def self.logger; config.logger; end
      delegate :logger, to: :config

      def initialize
      end

      def call(env)
        config.connection_class.new(self, env).process
      end

      def worker_pool
        @worker_pool ||= ActionCable::Server::Worker.pool(size: config.worker_pool_size)
      end

      def channel_classes
        @channel_classes ||= begin
          config.channel_paths.each { |channel_path| require channel_path }
          config.channel_class_names.collect { |name| name.constantize }
        end
      end

      def remote_connections
        @remote_connections ||= RemoteConnections.new(self)
      end

      def pubsub
        @pubsub ||= redis.pubsub
      end

      def redis
        @redis ||= EM::Hiredis.connect(config.redis[:url]).tap do |redis|
          redis.on(:reconnect_failed) do
            logger.info "[ActionCable] Redis reconnect failed."
            # logger.info "[ActionCable] Redis reconnected. Closing all the open connections."
            # @connections.map &:close
          end            
        end
      end

      def connection_identifiers
        config.connection_class.identifiers
      end
    end
  end
end