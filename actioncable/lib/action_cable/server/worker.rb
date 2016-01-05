require 'active_support/callbacks'
require 'concurrent'

module ActionCable
  module Server
    # Worker used by Server.send_async to do connection work in threads. Only for internal use.
    class Worker
      include ActiveSupport::Callbacks

      define_callbacks :work
      include ActiveRecordConnectionManagement

      def initialize(max_size=5)
        @pool = Concurrent::ThreadPoolExecutor.new(
          min_threads: 1,
          max_threads: max_size,
          max_queue: 0,
        )
      end

      def connection
        Thread.current[:connection] || raise("No connection set")
      end

      def async_invoke(receiver, method, *args)
        @pool.post do
          invoke(receiver, method, *args)
        end
      end

      def invoke(receiver, method, *args)
        begin
          Thread.current[:connection] = receiver

          run_callbacks :work do
            receiver.send method, *args
          end
        rescue Exception => e
          logger.error "There was an exception - #{e.class}(#{e.message})"
          logger.error e.backtrace.join("\n")

          receiver.handle_exception if receiver.respond_to?(:handle_exception)
        ensure
          Thread.current[:connection] = nil
        end
      end

      def async_run_periodic_timer(channel, callback)
        @pool.post do
          run_periodic_timer(channel, callback)
        end
      end

      def run_periodic_timer(channel, callback)
        begin
          Thread.current[:connection] = channel.connection

          run_callbacks :work do
            callback.respond_to?(:call) ? channel.instance_exec(&callback) : channel.send(callback)
          end
        ensure
          Thread.current[:connection] = nil
        end
      end

      private

        def logger
          ActionCable.server.logger
        end
    end
  end
end
