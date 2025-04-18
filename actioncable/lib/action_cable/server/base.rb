# frozen_string_literal: true

# :markup: markdown

require "monitor"

module ActionCable
  module Server
    # # Action Cable Server Base
    #
    # A singleton ActionCable::Server instance is available via ActionCable.server.
    # It's used by the Rack process that starts the Action Cable server, but is also
    # used by the user to reach the RemoteConnections object, which is used for
    # finding and disconnecting connections across all servers.
    #
    # Also, this is the server instance used for broadcasting. See Broadcasting for
    # more information.
    class Base
      include ActionCable::Server::Broadcasting
      include ActionCable::Server::Connections

      cattr_accessor :config, instance_accessor: false, default: ActionCable::Server::Configuration.new

      attr_reader :config

      def self.logger; config.logger; end
      delegate :logger, to: :config

      attr_reader :mutex

      def initialize(config: self.class.config)
        @config = config
        @mutex = Monitor.new
        @remote_connections = @event_loop = @worker_pool = @pubsub = nil
      end

      # Called by Rack to set up the server.
      def call(env)
        return config.health_check_application.call(env) if env["PATH_INFO"] == config.health_check_path
        setup_heartbeat_timer
        config.connection_class.call.new(self, env).process
      end

      # Disconnect all the connections identified by `identifiers` on this server or
      # any others via RemoteConnections.
      def disconnect(identifiers)
        remote_connections.where(identifiers).disconnect
      end

      def restart
        connections.each do |connection|
          connection.close(reason: ActionCable::INTERNAL[:disconnect_reasons][:server_restart])
        end

        @mutex.synchronize do
          # Shutdown the worker pool
          @worker_pool.halt if @worker_pool
          @worker_pool = nil

          # Shutdown the pub/sub adapter
          @pubsub.shutdown if @pubsub
          @pubsub = nil
        end
      end

      # Gateway to RemoteConnections. See that class for details.
      def remote_connections
        @remote_connections || @mutex.synchronize { @remote_connections ||= RemoteConnections.new(self) }
      end

      def event_loop
        @event_loop || @mutex.synchronize { @event_loop ||= ActionCable::Connection::StreamEventLoop.new }
      end

      # The worker pool is where we run connection callbacks and channel actions. We
      # do as little as possible on the server's main thread. The worker pool is an
      # executor service that's backed by a pool of threads working from a task queue.
      # The thread pool size maxes out at 4 worker threads by default. Tune the size
      # yourself with `config.action_cable.worker_pool_size`.
      #
      # Using Active Record, Redis, etc within your channel actions means you'll get a
      # separate connection from each thread in the worker pool. Plan your deployment
      # accordingly: 5 servers each running 5 Puma workers each running an 8-thread
      # worker pool means at least 200 database connections.
      #
      # Also, ensure that your database connection pool size is as least as large as
      # your worker pool size. Otherwise, workers may oversubscribe the database
      # connection pool and block while they wait for other workers to release their
      # connections. Use a smaller worker pool or a larger database connection pool
      # instead.
      def worker_pool
        @worker_pool || @mutex.synchronize { @worker_pool ||= ActionCable::Server::Worker.new(max_size: config.worker_pool_size) }
      end

      # Adapter used for all streams/broadcasting.
      def pubsub
        @pubsub || @mutex.synchronize { @pubsub ||= config.pubsub_adapter.new(self) }
      end

      # All of the identifiers applied to the connection class associated with this
      # server.
      def connection_identifiers
        config.connection_class.call.identifiers
      end
    end

    ActiveSupport.run_load_hooks(:action_cable, Base.config)
  end
end
