require 'thread'

module ActionCable
  module Server
    # A singleton ActionCable::Server instance is available via ActionCable.server. It's used by the Rack process that starts the Action Cable server, but
    # is also used by the user to reach the RemoteConnections object, which is used for finding and disconnecting connections across all servers.
    #
    # Also, this is the server instance used for broadcasting. See Broadcasting for more information.
    class Base
      include ActionCable::Server::Broadcasting
      include ActionCable::Server::Connections

      cattr_accessor(:config, instance_accessor: true) { ActionCable::Server::Configuration.new }

      def self.logger; config.logger; end
      delegate :logger, to: :config

      attr_reader :mutex

      def initialize
        @mutex = Mutex.new
        @remote_connections = @stream_event_loop = @worker_pool = @channel_classes = @pubsub = nil
      end

      # Called by Rack to setup the server.
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
        @remote_connections || @mutex.synchronize { @remote_connections ||= RemoteConnections.new(self) }
      end

      def stream_event_loop
        @stream_event_loop || @mutex.synchronize { @stream_event_loop ||= ActionCable::Connection::StreamEventLoop.new }
      end

      # The thread worker pool for handling all the connection work on this server. Default size is set by config.worker_pool_size.
      def worker_pool
        @worker_pool || @mutex.synchronize { @worker_pool ||= ActionCable::Server::Worker.new(max_size: config.worker_pool_size) }
      end

      # Requires and returns a hash of all of the channel class constants, which are keyed by name.
      def channel_classes
        @channel_classes || @mutex.synchronize do
          @channel_classes ||= begin
            config.channel_paths.each { |channel_path| require channel_path }
            config.channel_class_names.each_with_object({}) { |name, hash| hash[name] = name.constantize }
          end
        end
      end

      # Adapter used for all streams/broadcasting.
      def pubsub
        @pubsub || @mutex.synchronize { @pubsub ||= config.pubsub_adapter.new(self) }
      end

      # All of the identifiers applied to the connection class associated with this server.
      def connection_identifiers
        config.connection_class.identifiers
      end
    end

    ActiveSupport.run_load_hooks(:action_cable, Base.config)
  end
end
