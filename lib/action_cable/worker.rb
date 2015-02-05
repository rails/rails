module ActionCable
  class Worker
    include ActiveSupport::Callbacks
    include Celluloid

    define_callbacks :work

    def received_data(connection, data)
      run_callbacks :work do
        connection.received_data(data)
      end
    end

    def cleanup_subscriptions(connection)
      run_callbacks :work do
        connection.cleanup_subscriptions
      end
    end

    def run_periodic_timer(channel, callback)
      run_callbacks :work do
        callback.respond_to?(:call) ? channel.instance_exec(&callback) : channel.send(callback)
      end
    end

  end
end
