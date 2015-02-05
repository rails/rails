module ActionCable
  class Worker
    include ActiveSupport::Callbacks
    include Celluloid

    define_callbacks :work

    def invoke(receiver, method, *args)
      run_callbacks :work do
        receiver.send method, *args
      end
    end

    def run_periodic_timer(channel, callback)
      run_callbacks :work do
        callback.respond_to?(:call) ? channel.instance_exec(&callback) : channel.send(callback)
      end
    end

  end
end
