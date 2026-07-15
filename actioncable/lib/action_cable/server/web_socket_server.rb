# frozen_string_literal: true

require "monitor"

module ActionCable
  module Server
    # A default WebSocket server implementation with Rack interface and
    # a thread-pool executor to process user commands and broadcasting callbacks
    class WebSocketServer
      BEAT_INTERVAL = 3

      attr_reader :server
      delegate :config, :executor, to: :server

      def initialize(server)
        @server = server
        @mutex = Monitor.new
        @event_loop = @worker_pool = @heartbeat_timer = nil
      end

      # Called by Rack to set up the server.
      def call(env)
        return config.health_check_application.call(env) if env["PATH_INFO"] == config.health_check_path
        setup_heartbeat_timer
        Socket.new(self, env).process
      end

      def restart
        @mutex.synchronize do
          # Shutdown the heartbeat timer
          @heartbeat_timer.shutdown if @heartbeat_timer
          @heartbeat_timer = nil

          # Shutdown the worker pool
          @worker_pool.halt if @worker_pool
          @worker_pool = nil
        end
      end

      # WebSocket connection implementations differ on when they'll mark a connection
      # as stale. We basically never want a connection to go stale, as you then can't
      # rely on being able to communicate with the connection. To solve this, a 3
      # second heartbeat runs on all connections. If the beat fails, we automatically
      # disconnect.
      def setup_heartbeat_timer
        @heartbeat_timer ||= executor.timer(BEAT_INTERVAL) do
          executor.post { server.each_connection(&:beat) }
        end
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
    end
  end
end
