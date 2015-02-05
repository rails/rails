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
      connection.cleanup_subscriptions
    end

  end
end
