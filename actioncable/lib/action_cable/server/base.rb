# frozen_string_literal: true

# :markup: markdown

require "monitor"

module ActionCable
  module Server
    # A wrapper over ConcurrentRuby::ThreadPoolExecutor and Concurrent::TimerTask
    class ThreadedExecutor # :nodoc:
      def initialize(max_size: 10)
        @executor = Concurrent::ThreadPoolExecutor.new(
          name: "ActionCable server",
          min_threads: 1,
          max_threads: max_size,
          max_queue: 0,
        )
      end

      def post(task = nil, &block)
        task ||= block
        @executor << task
      end

      def timer(interval, &block)
        Concurrent::TimerTask.new(execution_interval: interval, &block).tap(&:execute)
      end

      def shutdown = @executor.shutdown
    end

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
        @remote_connections = @event_loop = @worker_pool = @executor = @pubsub = nil
      end

      # Called by Rack to set up the server.
      def call(env)
        return config.health_check_application.call(env) if env["PATH_INFO"] == config.health_check_path
        setup_heartbeat_timer
        Socket.new(self, env).process
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

          # Shutdown the executor
          @executor.shutdown if @executor
          @executor = nil

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
        @event_loop || @mutex.synchronize { @event_loop ||= StreamEventLoop.new }
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

      # Executor is used by various actions within Action Cable (e.g., pub/sub operations) to run code asynchronously.
      def executor
        @executor || @mutex.synchronize { @executor ||= ThreadedExecutor.new(max_size: config.executor_pool_size) }
      end

      # Adapter used for all streams/broadcasting.
      def pubsub
        @pubsub || (executor && @mutex.synchronize { @pubsub ||= config.pubsub_adapter.new(self) })
      end

      # All of the identifiers applied to the connection class associated with this
      # server.
      def connection_identifiers
        config.connection_class.call.identifiers
      end

      # Tags are declared in the server but computed in the connection. This allows us per-connection tailored tags.
      # You can pass request object either directly or via block to lazily evaluate it.
      def new_tagged_logger(request = nil, &block)
        TaggedLoggerProxy.new logger,
          tags: config.log_tags.map { |tag| tag.respond_to?(:call) ? tag.call(request ||= block.call) : tag.to_s.camelize }
      end

      # Check if the request origin is allowed to connect to the Action Cable server.
      def allow_request_origin?(env)
        return true if config.disable_request_forgery_protection

        proto = Rack::Request.new(env).ssl? ? "https" : "http"
        if config.allow_same_origin_as_host && env["HTTP_ORIGIN"] == "#{proto}://#{env['HTTP_HOST']}"
          true
        elsif Array(config.allowed_request_origins).any? { |allowed_origin|  allowed_origin === env["HTTP_ORIGIN"] }
          true
        else
          logger.error("Request origin not allowed: #{env['HTTP_ORIGIN']}")
          false
        end
      end
    end

    ActiveSupport.run_load_hooks(:action_cable, Base.config)
  end
end
