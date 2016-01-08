# FIXME: Cargo culted fix from https://github.com/celluloid/celluloid-pool/issues/10
require 'celluloid/current'

require 'em-hiredis'

module ActionCable
  module Server
    # A singleton ActionCable::Server instance is available via ActionCable.server. It's used by the rack process that starts the cable server, but
    # also by the user to reach the RemoteConnections instead for finding and disconnecting connections across all servers.
    #
    # Also, this is the server instance used for broadcasting. See Broadcasting for details.
    class Base
      include ActionCable::Server::Broadcasting
      include ActionCable::Server::Connections

      cattr_accessor(:config, instance_accessor: true) { ActionCable::Server::Configuration.new }

      def self.logger; config.logger; end
      delegate :logger, to: :config

      def initialize
      end

      # Called by rack to setup the server.
      def call(env)
        setup_heartbeat_timer
        config.connection_class.new(self, env).process
      end

      # Disconnect all the connections identified by `identifiers` on this server or any others via RemoteConnections.
      def disconnect(identifiers)
        remote_connections.where(identifiers).disconnect
      end

      # Gateway to RemoteConnections. See that class for details.
      def remote_connections
        @remote_connections ||= RemoteConnections.new(self)
      end

      # The thread worker pool for handling all the connection work on this server. Default size is set by config.worker_pool_size.
      def worker_pool
        @worker_pool ||= ActionCable::Server::Worker.pool(size: config.worker_pool_size)
      end

      # Requires and returns a hash of all the channel class constants keyed by name.
      def channel_classes
        @channel_classes ||= begin
          config.channel_paths.each { |channel_path| require channel_path }
          config.channel_class_names.each_with_object({}) { |name, hash| hash[name] = name.constantize }
        end
      end

      # The redis pubsub adapter used for all streams/broadcasting.
      def pubsub
        @pubsub ||= redis.pubsub
      end

      # The EventMachine Redis instance used by the pubsub adapter.
      def redis
        @redis ||= EM::Hiredis.connect(config.redis[:url]).tap do |redis|
          redis.on(:reconnect_failed) do
            logger.info "[ActionCable] Redis reconnect failed."
            # logger.info "[ActionCable] Redis reconnected. Closing all the open connections."
            # @connections.map &:close
          end
        end
      end

      # All the identifiers applied to the connection class associated with this server.
      def connection_identifiers
        config.connection_class.identifiers
      end
    end

    ActiveSupport.run_load_hooks(:action_cable, Base.config)
  end
end
