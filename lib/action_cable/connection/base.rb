module ActionCable
  module Connection
    class Base
      include Identification
      include InternalChannel

      attr_reader :server, :env
      delegate :worker_pool, :pubsub, to: :server

      attr_reader :logger

      def initialize(server, env)
        @started_at = Time.now

        @server, @env = server, env

        @logger = TaggedLoggerProxy.new(server.logger, tags: log_tags)

        @heartbeat     = ActionCable::Connection::Heartbeat.new(self)
        @subscriptions = ActionCable::Connection::Subscriptions.new(self)
      end

      def process
        logger.info started_request_message

        if websocket?
          @websocket = Faye::WebSocket.new(@env)

          @websocket.on(:open) do |event|
            heartbeat.start
            worker_pool.async.invoke(self, :on_open)
          end

          @websocket.on(:message) do |event|
            message = event.data

            if message.is_a?(String)
              if accepting_messages?
                worker_pool.async.invoke(self, :receive, message)
              else
                queue_message message
              end
            else
              logger.error "Couldn't handle non-string message: #{message.class}"
            end
          end

          @websocket.on(:close) do |event|
            logger.info finished_request_message

            heartbeat.stop
            worker_pool.async.invoke(self, :on_close)
          end

          @websocket.rack_response
        else
          logger.info finished_request_message

          respond_to_invalid_request
        end
      end

      def receive(data_in_json)
        if websocket_alive?
          data = ActiveSupport::JSON.decode data_in_json

          case data['command']
          when 'subscribe'   then subscriptions.add data
          when 'unsubscribe' then subscriptions.remove data
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

      def close
        logger.error "Closing connection"
        @websocket.close
      end


      def statistics
        {
          identifier:    connection_identifier,
          started_at:    @started_at,
          subscriptions: subscriptions.identifiers
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
        attr_reader :heartbeat, :subscriptions

        def on_open
          server.add_connection(self)

          connect if respond_to?(:connect)
          subscribe_to_internal_channel

          ready_to_accept_messages
          process_pending_messages
        end


        def accepting_messages?
          @accept_messages
        end

        def ready_to_accept_messages
          @accept_messages = true
        end

        def queue_message(message)
          @pending_messages ||= []
          @pending_messages << message
        end

        def process_pending_messages
          worker_pool.async.invoke(self, :receive, @pending_messages.shift) until @pending_messages.empty?
        end


        def on_close
          server.remove_connection(self)

          subscriptions.cleanup
          unsubscribe_from_internal_channel
          disconnect if respond_to?(:disconnect)
        end


        def process_message(message)
          subscriptions.find(message['identifier']).perform_action(ActiveSupport::JSON.decode(message['data']))
        rescue Exception => e
          logger.error "Could not process message (#{message.inspect})"
          log_exception(e)
        end


        def respond_to_invalid_request
          [ 404, { 'Content-Type' => 'text/plain' }, [ 'Page not found' ] ]
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
