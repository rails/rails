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
        logger.info "[ActionCable] #{started_request_message}"

        if websocket?
          @subscriptions = {}

          @websocket = Faye::WebSocket.new(@env)

          @websocket.on(:open) do |event|
            broadcast_ping_timestamp
            @ping_timer = EventMachine.add_periodic_timer(PING_INTERVAL) { broadcast_ping_timestamp }
            worker_pool.async.invoke(self, :initialize_connection)
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
            logger.info "[ActionCable] #{finished_request_message}"

            worker_pool.async.invoke(self, :on_connection_closed)
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
        logger.info "[ActionCable] Sending data: #{data}"
        @websocket.send data
      end

      def handle_exception
        logger.error "[ActionCable] Closing connection"

        @websocket.close
      end

      private
        def initialize_connection
          connect if respond_to?(:connect)
          register_connection

          @accept_messages = true
          worker_pool.async.invoke(self, :received_data, @pending_messages.shift) until @pending_messages.empty?
        end

        def on_connection_closed
          cleanup_subscriptions
          cleanup_internal_redis_subscriptions
          disconnect if respond_to?(:disconnect)
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
          log_exception(e)
        end

        def process_message(message)
          if @subscriptions[message['identifier']]
            @subscriptions[message['identifier']].receive_data(ActiveSupport::JSON.decode message['data'])
          else
            logger.error "[ActionCable] Unable to process message because no subscription was found (#{message.inspect})"
          end
        rescue Exception => e
          logger.error "[ActionCable] Could not process message (#{message.inspect})"
          log_exception(e)
        end

        def unsubscribe_channel(data)
          logger.info "[ActionCable] Unsubscribing from channel: #{data['identifier']}"
          @subscriptions[data['identifier']].unsubscribe
          @subscriptions.delete(data['identifier'])
        end

        def invalid_request
          logger.info "[ActionCable] #{finished_request_message}"
          [404, {'Content-Type' => 'text/plain'}, ['Page not found']]
        end

        def websocket_alive?
          @websocket && @websocket.ready_state == Faye::WebSocket::API::OPEN
        end

        def request
          @request ||= ActionDispatch::Request.new(env)
        end

        def websocket?
          @is_websocket ||= Faye::WebSocket.websocket?(@env)
        end

        def started_request_message
          'Started %s "%s"%s for %s at %s' % [
            request.request_method,
            request.filtered_path,
            websocket? ? ' [Websocket]' : '',
            request.ip,
            Time.now.to_default_s ]
        end

        def finished_request_message
          'Finished "%s"%s for %s at %s' % [
            request.filtered_path,
            websocket? ? ' [Websocket]' : '',
            request.ip,
            Time.now.to_default_s ]
        end

        def log_exception(e)
          logger.error "[ActionCable] There was an exception - #{e.class}(#{e.message})"
          logger.error e.backtrace.join("\n")
        end
    end
  end
end
