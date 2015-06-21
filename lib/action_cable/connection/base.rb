module ActionCable
  module Connection
    class Base
      include Identification
      include InternalChannel

      PING_INTERVAL = 3
      
      attr_reader :server, :env
      delegate :worker_pool, :pubsub, to: :server

      attr_reader :logger

      def initialize(server, env)
        @started_at = Time.now

        @server, @env = server, env

        @accept_messages  = false
        @pending_messages = []

        @subscriptions = {}

        @logger = TaggedLoggerProxy.new(server.logger, tags: log_tags)
      end

      def process
        logger.info started_request_message

        if websocket?
          @websocket = Faye::WebSocket.new(@env)

          @websocket.on(:open) do |event|
            transmit_ping_timestamp
            @ping_timer = EventMachine.add_periodic_timer(PING_INTERVAL) { transmit_ping_timestamp }
            worker_pool.async.invoke(self, :on_open)
          end

          @websocket.on(:message) do |event|
            message = event.data

            if message.is_a?(String)
              if @accept_messages
                worker_pool.async.invoke(self, :receive, message)
              else
                @pending_messages << message
              end
            end
          end

          @websocket.on(:close) do |event|
            logger.info finished_request_message

            worker_pool.async.invoke(self, :on_close)
            EventMachine.cancel_timer(@ping_timer) if @ping_timer
          end

          @websocket.rack_response
        else
          invalid_request
        end
      end

      def receive(data_in_json)
        if websocket_alive?
          data = ActiveSupport::JSON.decode data_in_json

          case data['command']
          when 'subscribe'   then subscribe_channel data
          when 'unsubscribe' then unsubscribe_channel data
          when 'message'     then process_message data
          else
            logger.error "Received unrecognized command in #{data.inspect}"
          end
        else
          logger.error "Received data without a live websocket (#{data.inspect})"
        end
      end

      def transmit(data)
        @websocket.send data
      end


      def handle_exception
        close_connection
      end

      def close_connection
        logger.error "Closing connection"
        @websocket.close
      end


      def statistics
        {
          identifier:    connection_identifier,
          started_at:    @started_at,
          subscriptions: @subscriptions.keys
        }
      end


      protected
        def request
          @request ||= ActionDispatch::Request.new(Rails.application.env_config.merge(env))
        end

        def cookies
          request.cookie_jar
        end


      private
        def on_open
          server.add_connection(self)

          connect if respond_to?(:connect)
          subscribe_to_internal_channel

          @accept_messages = true
          worker_pool.async.invoke(self, :receive, @pending_messages.shift) until @pending_messages.empty?
        end

        def on_close
          server.remove_connection(self)

          cleanup_subscriptions
          unsubscribe_from_internal_channel
          disconnect if respond_to?(:disconnect)
        end

        def cleanup_subscriptions
          @subscriptions.each do |id, channel|
            channel.perform_disconnection
          end
        end


        def transmit_ping_timestamp
          transmit({ identifier: '_ping', message: Time.now.to_i }.to_json)
        end

        def subscribe_channel(data)
          id_key = data['identifier']
          id_options = ActiveSupport::JSON.decode(id_key).with_indifferent_access

          subscription_klass = server.registered_channels.detect { |channel_klass| channel_klass.find_name == id_options[:channel] }

          if subscription_klass
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
            @subscriptions[message['identifier']].perform_action(ActiveSupport::JSON.decode message['data'])
          else
            raise "Unable to process message because no subscription was found (#{message.inspect})"
          end
        rescue Exception => e
          logger.error "Could not process message (#{message.inspect})"
          log_exception(e)
        end

        def unsubscribe_channel(data)
          logger.info "Unsubscribing from channel: #{data['identifier']}"
          @subscriptions[data['identifier']].perform_disconnection
          @subscriptions.delete(data['identifier'])
        end

        def invalid_request
          logger.info finished_request_message
          [404, {'Content-Type' => 'text/plain'}, ['Page not found']]
        end

        def websocket_alive?
          @websocket && @websocket.ready_state == Faye::WebSocket::API::OPEN
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
          logger.error "There was an exception: #{e.class} - #{e.message}"
          logger.error e.backtrace.join("\n")
        end

        def log_tags
          server.log_tags.map { |tag| tag.respond_to?(:call) ? tag.call(request) : tag.to_s.camelize }
        end
    end
  end
end
