module ActionCable
  module Connection
    class Base
      include InternalChannel, Identifier

      PING_INTERVAL = 3

      class_attribute :identifiers
      self.identifiers = Set.new

      def self.identified_by(*identifiers)
        self.identifiers += identifiers
      end

      attr_reader :env, :server, :logger
      delegate :worker_pool, :pubsub, to: :server

      def initialize(server, env)
        @started_at = Time.now

        @server = server
        @env = env
        @accept_messages = false
        @pending_messages = []
        @subscriptions = {}

        @logger = TaggedLoggerProxy.new(server.logger, tags: [ 'ActionCable' ])
        @logger.add_tags(*logger_tags)
      end

      def process
        logger.info started_request_message

        if websocket?
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
            logger.info finished_request_message

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
        logger.info "Sending data: #{data}"
        @websocket.send data
      end

      def statistics
        {
          identifier: connection_identifier,
          started_at: @started_at,
          subscriptions: @subscriptions.keys
        }
      end

      def handle_exception
        close_connection
      end

      def close_connection
        logger.error "Closing connection"

        @websocket.close
      end

      protected
        def initialize_connection
          server.add_connection(self)

          connect if respond_to?(:connect)
          subscribe_to_internal_channel

          @accept_messages = true
          worker_pool.async.invoke(self, :received_data, @pending_messages.shift) until @pending_messages.empty?
        end

        def on_connection_closed
          server.remove_connection(self)

          cleanup_subscriptions
          unsubscribe_from_internal_channel
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
            logger.info "Subscribing to channel: #{id_key}"
            @subscriptions[id_key] = subscription_klass.new(self, id_key, id_options)
          else
            logger.error "Subscription class not found (#{data.inspect})"
          end
        rescue Exception => e
          logger.error "Could not subscribe to channel (#{data.inspect})"
          log_exception(e)
        end

        def process_message(message)
          if @subscriptions[message['identifier']]
            @subscriptions[message['identifier']].receive_data(ActiveSupport::JSON.decode message['data'])
          else
            log_exception "Unable to process message because no subscription was found (#{message.inspect})"
          end
        rescue Exception => e
          logger.error "Could not process message (#{message.inspect})"
          log_exception(e)
        end

        def unsubscribe_channel(data)
          logger.info "Unsubscribing from channel: #{data['identifier']}"
          @subscriptions[data['identifier']].unsubscribe
          @subscriptions.delete(data['identifier'])
        end

        def invalid_request
          logger.info "#{finished_request_message}"
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
          logger.error "There was an exception - #{e.class}(#{e.message})"
          logger.error e.backtrace.join("\n")
        end

        def logger_tags
          []
        end
    end
  end
end
