module ActionCable
  class Worker
    include ActiveSupport::Callbacks
    include Celluloid

    define_callbacks :work

    def invoke(receiver, method, *args)
      run_callbacks :work do
        receiver.send method, *args
      end
    rescue Exception => e
      logger.error "[ActionCable] There was an exception - #{e.class}(#{e.message})"
      logger.error e.backtrace.join("\n")

      receiver.handle_exception if receiver.respond_to?(:handle_exception)
    end

    def run_periodic_timer(channel, callback)
      run_callbacks :work do
        callback.respond_to?(:call) ? channel.instance_exec(&callback) : channel.send(callback)
      end
    end

    private
      def logger
        ActionCable::Server.logger
      end
  end
end
