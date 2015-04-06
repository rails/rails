module ActionCable
  module Connection
    class Base
      include Registry

      PING_INTERVAL = 3

      attr_reader :env, :server
      delegate :worker_pool, :pubsub, :logger, to: :server

      def initialize(server, env)
        @server = server
        @env = env
        @accept_messages = false
        @pending_messages = []
      end

      def process
        if Faye::WebSocket.websocket?(@env)
          @subscriptions = {}

          @websocket = Faye::WebSocket.new(@env)

          @websocket.on(:open) do |event|
            broadcast_ping_timestamp
            @ping_timer = EventMachine.add_periodic_timer(PING_INTERVAL) { broadcast_ping_timestamp }
            worker_pool.async.invoke(self, :initialize_client)
          end

          @websocket.on(:message) do |event|
            message = event.data

            if message.is_a?(String)
              if @accept_messages
                worker_pool.async.invoke(self, :received_data, message)
              else
                @pending_messages << message
              end
            end
          end

          @websocket.on(:close) do |event|
            worker_pool.async.invoke(self, :cleanup_subscriptions)
            worker_pool.async.invoke(self, :cleanup_internal_redis_subscriptions)
            worker_pool.async.invoke(self, :disconnect) if respond_to?(:disconnect)

            EventMachine.cancel_timer(@ping_timer) if @ping_timer
          end

          @websocket.rack_response
        else
          invalid_request
        end
      end

      def received_data(data)
        return unless websocket_alive?

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

      def handle_exception
        logger.error "[ActionCable] Closing connection"

        @websocket.close
      end

      private
        def initialize_client
          connect if respond_to?(:connect)
          register_connection

          @accept_messages = true
          worker_pool.async.invoke(self, :received_data, @pending_messages.shift) until @pending_messages.empty?
        end

        def broadcast_ping_timestamp
          broadcast({ identifier: '_ping', message: Time.now.to_i }.to_json)
        end

        def subscribe_channel(data)
          id_key = data['identifier']
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

          subscription_klass = server.registered_channels.detect { |channel_klass| channel_klass.find_name == id_options[:channel] }

          if subscription_klass
            logger.info "[ActionCable] Subscribing to channel: #{id_key}"
            @subscriptions[id_key] = subscription_klass.new(self, id_key, id_options)
          else
            logger.error "[ActionCable] Subscription class not found (#{data.inspect})"
          end
        rescue Exception => e
          logger.error "[ActionCable] Could not subscribe to channel (#{data.inspect})"
          logger.error e.backtrace.join("\n")
        end

        def process_message(message)
          if @subscriptions[message['identifier']]
            @subscriptions[message['identifier']].receive_data(ActiveSupport::JSON.decode message['data'])
          else
            logger.error "[ActionCable] Unable to process message because no subscription found (#{message.inspect})"
          end
        rescue Exception => e
          logger.error "[ActionCable] Could not process message (#{data.inspect})"
          logger.error e.backtrace.join("\n")
        end

        def unsubscribe_channel(data)
          logger.info "[ActionCable] Unsubscribing from channel: #{data['identifier']}"
          @subscriptions[data['identifier']].unsubscribe
          @subscriptions.delete(data['identifier'])
        end

        def invalid_request
          [404, {'Content-Type' => 'text/plain'}, ['Page not found']]
        end

        def websocket_alive?
          @websocket && @websocket.ready_state == Faye::WebSocket::API::OPEN
        end

    end
  end
end
