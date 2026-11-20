# frozen_string_literal: true

require "active_support/callbacks"
require "active_support/core_ext/module/attribute_accessors_per_thread"
require "concurrent/executor/thread_pool_executor"

module ActionCable
  module Server
    # Worker used by Server.send_async to do connection work in threads.
    class Worker # :nodoc:
      include ActiveSupport::Callbacks

      thread_mattr_accessor :connection
      define_callbacks :work
      include ActiveRecordConnectionManagement

      attr_reader :executor

      def initialize(max_size: 5)
        @executor = Concurrent::ThreadPoolExecutor.new(
          name: "ActionCable-server",
          min_threads: 1,
          max_threads: max_size,
          max_queue: 0,
        )
      end

      # Stop accepting work. Work posted after this is rejected. Work already queued,
      # including work waiting behind a connection's earlier jobs, still runs.
      def halt
        @executor.shutdown
      end

      def stopping?
        @executor.shuttingdown?
      end

      def work(connection, &block)
        self.connection = connection

        run_callbacks :work, &block
      ensure
        self.connection = nil
      end

      def async_exec(receiver, *args, connection:, &block)
        async_invoke receiver, :instance_exec, *args, connection: connection, &block
      end

      def async_invoke(receiver, method, *args, connection: receiver, executor: @executor, &block)
        executor.post do
          invoke(receiver, method, *args, connection: connection, &block)
        end
      end

      def invoke(receiver, method, *args, connection:, &block)
        work(connection) do
          receiver.send method, *args, &block
        rescue Exception => e
          logger.error "There was an exception - #{e.class}(#{e.message})"
          logger.error e.backtrace.join("\n")

          receiver.handle_exception if receiver.respond_to?(:handle_exception)
        end
      end

      private
        def logger
          ActionCable.server.logger
        end
    end
  end
end
