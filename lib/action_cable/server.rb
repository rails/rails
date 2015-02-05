module ActionCable
  class Server
    class_attribute :registered_channels
    self.registered_channels = Set.new

    class_attribute :worker_pool_size
    self.worker_pool_size = 100

    class << self
      def register_channels(*channel_classes)
        self.registered_channels += channel_classes
      end

      def call(env)
        new(env).process
      end

      def worker_pool
        @worker_pool ||= ActionCable::Worker.pool(size: worker_pool_size)
      end
    end

    def initialize(env)
      @env = env
    end

    def process
      if Faye::WebSocket.websocket?(@env)
        @subscriptions = {}

        @websocket = Faye::WebSocket.new(@env)

        @websocket.on(:message) do |event|
          message = event.data
          worker_pool.async.invoke(self, :received_data, message) if message.is_a?(String)
        end

        @websocket.on(:close) do |event|
          worker_pool.async.invoke(self, :cleanup_subscriptions)
        end

        @websocket.rack_response
      else
        invalid_request
      end
    end

    def received_data(data)
      data = ActiveSupport::JSON.decode data

      case data['action']
      when 'subscribe'
        subscribe_channel(data)
      when 'unsubscribe'
        unsubscribe_channel(data)
      when 'message'
        process_message(data)
      end
    end

    def cleanup_subscriptions
      @subscriptions.each do |id, channel|
        channel.unsubscribe
      end
    end

    def broadcast(data)
      @websocket.send data
    end

    def worker_pool
      self.class.worker_pool
    end

    private
      def subscribe_channel(data)
        id_key = data['identifier']
        id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

        subscription_klass = registered_channels.detect { |channel_klass| channel_klass.find_name == id_options[:channel] }

        if subscription_klass
          @subscriptions[id_key] = subscription_klass.new(self, id_key, id_options)
        else
          # No channel found
        end
      end

      def process_message(message)
        id_key = message['identifier']

        if @subscriptions[id_key]
          @subscriptions[id_key].receive(ActiveSupport::JSON.decode message['data'])
        end
      end

      def unsubscribe_channel(data)
        id_key = data['identifier']
        @subscriptions[id_key].unsubscribe
        @subscriptions.delete(id_key)
      end

      def invalid_request
        [404, {'Content-Type' => 'text/plain'}, ['Page not found']]
      end
  end
end
