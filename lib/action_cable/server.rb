module ActionCable
  class Server
    class_attribute :registered_channels
    self.registered_channels = Set.new

    class_attribute :worker_pool_size
    self.worker_pool_size = 100

    cattr_accessor(:logger, instance_reader: true) { Rails.logger }

    PING_INTERVAL = 3

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

    attr_reader :env

    def initialize(env)
      @env = env
    end

    def process
      if Faye::WebSocket.websocket?(@env)
        @subscriptions = {}

        @websocket = Faye::WebSocket.new(@env)

        @websocket.on(:open) do |event|
          broadcast_ping_timestamp
          @ping_timer = EventMachine.add_periodic_timer(PING_INTERVAL) { broadcast_ping_timestamp }
          worker_pool.async.invoke(self, :connect) if respond_to?(:connect)
        end

        @websocket.on(:message) do |event|
          message = event.data
          worker_pool.async.invoke(self, :received_data, message) if message.is_a?(String)
        end

        @websocket.on(:close) do |event|
          worker_pool.async.invoke(self, :cleanup_subscriptions)
          worker_pool.async.invoke(self, :disconnect) if respond_to?(:disconnect)

          EventMachine.cancel_timer(@ping_timer) if @ping_timer
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
      logger.info "Sending data: #{data}"
      @websocket.send data
    end

    def worker_pool
      self.class.worker_pool
    end

    def request
      @request ||= ActionDispatch::Request.new(env)
    end

    def cookies
      request.cookie_jar
    end

    private
      def broadcast_ping_timestamp
        broadcast({ identifier: '_ping', message: Time.now.to_i }.to_json)
      end

      def subscribe_channel(data)
        id_key = data['identifier']
        id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

        subscription_klass = registered_channels.detect { |channel_klass| channel_klass.find_name == id_options[:channel] }

        if subscription_klass
          logger.info "Subscribing to channel: #{id_key}"
          @subscriptions[id_key] = subscription_klass.new(self, id_key, id_options)
        else
          logger.error "Unable to subscribe to channel: #{id_key}"
        end
      end

      def process_message(message)
        if @subscriptions[message['identifier']]
          @subscriptions[message['identifier']].receive_data(ActiveSupport::JSON.decode message['data'])
        else
          logger.error "Unable to process message: #{message}"
        end
      end

      def unsubscribe_channel(data)
        logger.info "Unsubscribing from channel: #{data['identifier']}"
        @subscriptions[data['identifier']].unsubscribe
        @subscriptions.delete(data['identifier'])
      end

      def invalid_request
        [404, {'Content-Type' => 'text/plain'}, ['Page not found']]
      end

  end
end
