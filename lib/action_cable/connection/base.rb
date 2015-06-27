module ActionCable
  module Connection
    class Base
      include Identification
      include InternalChannel

      attr_reader :server, :env
      delegate :worker_pool, :pubsub, to: :server

      attr_reader :logger

      def initialize(server, env)
        @server, @env = server, env

        @logger = initialize_tagged_logger

        @websocket      = ActionCable::Connection::WebSocket.new(env)
        @heartbeat      = ActionCable::Connection::Heartbeat.new(self)
        @subscriptions  = ActionCable::Connection::Subscriptions.new(self)
        @message_buffer = ActionCable::Connection::MessageBuffer.new(self)

        @started_at = Time.now
      end

      def process
        logger.info started_request_message

        if websocket.possible?
          websocket.on(:open)    { |event| send_async :on_open   }
          websocket.on(:message) { |event| on_message event.data }
          websocket.on(:close)   { |event| send_async :on_close  }
          
          websocket.rack_response
        else
          respond_to_invalid_request
        end
      end

      def receive(data_in_json)
        if websocket.alive?
          subscriptions.execute_command ActiveSupport::JSON.decode(data_in_json)
        else
          logger.error "Received data without a live websocket (#{data.inspect})"
        end
      end

      def transmit(data)
        websocket.transmit data
      end

      def close
        logger.error "Closing connection"
        websocket.close
      end


      def send_async(method, *arguments)
        worker_pool.async.invoke(self, method, *arguments)
      end

      def statistics
        { identifier: connection_identifier, started_at: @started_at, subscriptions: subscriptions.identifiers }
      end


      protected
        def request
          @request ||= ActionDispatch::Request.new(Rails.application.env_config.merge(env))
        end

        def cookies
          request.cookie_jar
        end


      private
        attr_reader :websocket
        attr_reader :heartbeat, :subscriptions, :message_buffer

        def on_open
          server.add_connection(self)

          connect if respond_to?(:connect)
          subscribe_to_internal_channel
          heartbeat.start

          message_buffer.process!
        end

        def on_message(message)
          message_buffer.append message
        end

        def on_close
          logger.info finished_request_message

          server.remove_connection(self)

          subscriptions.cleanup
          unsubscribe_from_internal_channel
          heartbeat.stop

          disconnect if respond_to?(:disconnect)
        end


        def respond_to_invalid_request
          logger.info finished_request_message
          [ 404, { 'Content-Type' => 'text/plain' }, [ 'Page not found' ] ]
        end


        # Tags are declared in the server but computed in the connection. This allows us per-connection tailored tags.
        def initialize_tagged_logger
          TaggedLoggerProxy.new server.logger, 
            tags: server.log_tags.map { |tag| tag.respond_to?(:call) ? tag.call(request) : tag.to_s.camelize }
        end

        def started_request_message
          'Started %s "%s"%s for %s at %s' % [
            request.request_method,
            request.filtered_path,
            websocket.possible? ? ' [Websocket]' : '',
            request.ip,
            Time.now.to_default_s ]
        end

        def finished_request_message
          'Finished "%s"%s for %s at %s' % [
            request.filtered_path,
            websocket.possible? ? ' [Websocket]' : '',
            request.ip,
            Time.now.to_default_s ]
        end
    end
  end
end
