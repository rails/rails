require 'active_support/callbacks'
require 'active_support/core_ext/module/attribute_accessors_per_thread'
require 'concurrent'

module ActionCable
  module Server
    # Worker used by Server.send_async to do connection work in threads.
    class Worker # :nodoc:
      include ActiveSupport::Callbacks

      thread_mattr_accessor :connection
      define_callbacks :work
      include ActiveRecordConnectionManagement

      def initialize(max_size: 5)
        @pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: 1,
          max_threads: max_size,
          max_queue: 0,
        )
      end

      # Stop processing work: any work that has not already started
      # running will be discarded from the queue
      def halt
        @pool.kill
      end

      def stopping?
        @pool.shuttingdown?
      end

      def work(connection)
        self.connection = connection

        run_callbacks :work do
          yield
        end
      ensure
        self.connection = nil
      end

      def async_invoke(receiver, method, *args)
        @pool.post do
          invoke(receiver, method, *args)
        end
      end

      def invoke(receiver, method, *args)
        work(receiver) do
          begin
            receiver.send method, *args
          rescue Exception => e
            logger.error "There was an exception - #{e.class}(#{e.message})"
            logger.error e.backtrace.join("\n")

            receiver.handle_exception if receiver.respond_to?(:handle_exception)
          end
        end
      end

      def async_run_periodic_timer(channel, callback)
        @pool.post do
          run_periodic_timer(channel, callback)
        end
      end

      def run_periodic_timer(channel, callback)
        work(channel.connection) do
          callback.respond_to?(:call) ? channel.instance_exec(&callback) : channel.send(callback)
        end
      end

      private

        def logger
          ActionCable.server.logger
        end
    end
  end
end
