require "action_dispatch"

module ActionCable
  module Connection
    class Base # :nodoc:
      attr_reader :server, :env, :client, :logger, :worker_pool, :protocol, :client
      delegate :event_loop, :pubsub, :config, to: :server

      def initialize(server, env, client_class: nil, coder: ActiveSupport::JSON)
        @server, @env = server, env

        @worker_pool = server.worker_pool
        @logger = new_tagged_logger

        @websocket      = ActionCable::Connection::WebSocket.new(env, self, event_loop)
        @message_buffer = ActionCable::Connection::MessageBuffer.new(self)

        @_internal_subscriptions = nil
        @started_at = Time.now

        client_class ||= config.connection_class.call
        @client = client_class.new(self, coder: coder)
      end

      # Called by the server when a new WebSocket connection is established. This configures the callbacks intended for overwriting by the user.
      # This method should not be called directly -- instead rely upon on the #connect (and #disconnect) callbacks.
      def process #:nodoc:
        logger.info started_request_message

        if websocket.possible? && allow_request_origin?
          respond_to_successful_request
        else
          respond_to_invalid_request
        end
      end

      # Decodes WebSocket messages and dispatches them to subscribed channels.
      # WebSocket message transfer encoding is always JSON.
      def receive(websocket_message) #:nodoc:
        send_async :dispatch_websocket_message, websocket_message
      end

      def dispatch_websocket_message(websocket_message) #:nodoc:
        if websocket.alive?
          client.handle_command websocket_message
        else
          logger.error "Ignoring message processed after the WebSocket was closed: #{websocket_message.inspect})"
        end
      end

      def transmit(websocket_message) # :nodoc:
        websocket.transmit websocket_message
      end

      # Close the WebSocket connection.
      def close
        websocket.close
      end

      # Invoke a method on the connection asynchronously through the pool of thread workers.
      def send_async(method, *arguments)
        worker_pool.async_invoke(self, method, *arguments)
      end

      # Return a basic hash of statistics for the connection keyed with <tt>identifier</tt>, <tt>started_at</tt>, <tt>subscriptions</tt>, and <tt>request_id</tt>.
      # This can be returned by a health check against the connection.
      def statistics
        {
          identifier: client.identifier,
          started_at: @started_at,
          subscriptions: client.subscriptions.identifiers,
          request_id: @env["action_dispatch.request_id"]
        }
      end

      def beat
        transmit type: ActionCable::INTERNAL[:message_types][:ping], message: Time.now.to_i
      end

      def on_open # :nodoc:
        send_async :handle_open
      end

      def on_message(message) # :nodoc:
        message_buffer.append message
      end

      def on_error(message) # :nodoc:
        # ignore
      end

      def on_close(reason, code) # :nodoc:
        send_async :handle_close
      end

      # TODO Change this to private once we've dropped Ruby 2.2 support.
      # Workaround for Ruby 2.2 "private attribute?" warning.
      protected
        attr_reader :websocket
        attr_reader :message_buffer

      private
        # The request that initiated the WebSocket connection is available here. This gives access to the environment, cookies, etc.
        def request # :doc:
          @request ||= begin
            environment = Rails.application.env_config.merge(env) if defined?(Rails.application) && Rails.application
            ActionDispatch::Request.new(environment || env)
          end
        end

        # The cookies of the request that initiated the WebSocket connection. Useful for performing authorization checks.
        def cookies # :doc:
          request.cookie_jar
        end

        def handle_open
          @protocol = websocket.protocol
          client.handle_connect

          message_buffer.process!
          server.add_connection(self)
        rescue ActionCable::Client::Authorization::UnauthorizedError
          respond_to_invalid_request
        end

        def handle_close
          logger.info finished_request_message

          server.remove_connection(self)

          client.handle_disconnect
        end

        def allow_request_origin?
          return true if server.config.disable_request_forgery_protection

          proto = Rack::Request.new(env).ssl? ? "https" : "http"
          if server.config.allow_same_origin_as_host && env["HTTP_ORIGIN"] == "#{proto}://#{env['HTTP_HOST']}"
            true
          elsif Array(server.config.allowed_request_origins).any? { |allowed_origin|  allowed_origin === env["HTTP_ORIGIN"] }
            true
          else
            logger.error("Request origin not allowed: #{env['HTTP_ORIGIN']}")
            false
          end
        end

        def respond_to_successful_request
          logger.info successful_request_message
          websocket.rack_response
        end

        def respond_to_invalid_request
          close if websocket.alive?

          logger.error invalid_request_message
          logger.info finished_request_message
          [ 404, { "Content-Type" => "text/plain" }, [ "Page not found" ] ]
        end

        # Tags are declared in the server but computed in the connection. This allows us per-connection tailored tags.
        def new_tagged_logger
          TaggedLoggerProxy.new server.logger,
            tags: server.config.log_tags.map { |tag| tag.respond_to?(:call) ? tag.call(request) : tag.to_s.camelize }
        end

        def started_request_message
          'Started %s "%s"%s for %s at %s' % [
            request.request_method,
            request.filtered_path,
            websocket.possible? ? " [WebSocket]" : "[non-WebSocket]",
            request.ip,
            Time.now.to_s ]
        end

        def finished_request_message
          'Finished "%s"%s for %s at %s' % [
            request.filtered_path,
            websocket.possible? ? " [WebSocket]" : "[non-WebSocket]",
            request.ip,
            Time.now.to_s ]
        end

        def invalid_request_message
          "Failed to upgrade to WebSocket (REQUEST_METHOD: %s, HTTP_CONNECTION: %s, HTTP_UPGRADE: %s)" % [
            env["REQUEST_METHOD"], env["HTTP_CONNECTION"], env["HTTP_UPGRADE"]
          ]
        end

        def successful_request_message
          "Successfully upgraded to WebSocket (REQUEST_METHOD: %s, HTTP_CONNECTION: %s, HTTP_UPGRADE: %s)" % [
            env["REQUEST_METHOD"], env["HTTP_CONNECTION"], env["HTTP_UPGRADE"]
          ]
        end
    end
  end
end
