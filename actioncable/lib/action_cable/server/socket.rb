# frozen_string_literal: true

require "action_dispatch"

module ActionCable
  module Server
    # This class encapsulates all the low-level logic of working with the underlying WebSocket conenctions
    # and delegate all the business-logic to the user-level connection object (e.g., ApplicationCable::Connection).
    # This connection object is also responsible for handling encoding and decoding of messages, so the user-level
    # connection object shouldn't know about such details.
    class Socket
      attr_reader :server, :env, :protocol, :logger, :connection
      private attr_reader :worker_pool

      delegate :event_loop, :pubsub, :config, to: :server

      def initialize(server, env, coder: ActiveSupport::JSON)
        @server, @env, @coder = server, env, coder

        @worker_pool = server.worker_pool
        @logger = server.new_tagged_logger { request }

        @websocket      = WebSocket.new(env, self, event_loop)
        @message_buffer = MessageBuffer.new(self)

        @protocol = nil
        @connection = config.connection_class.call.new(server, self)
      end

      # Called by the server when a new WebSocket connection is established.
      def process # :nodoc:
        logger.info started_request_message

        if websocket.possible? && server.allow_request_origin?(env)
          respond_to_successful_request
        else
          respond_to_invalid_request
        end
      end

      # Methods used by the delegate (i.e., an application connection)

      # Send a non-serialized message over the WebSocket connection.
      def transmit(cable_message)
        return unless websocket.alive?

        websocket.transmit encode(cable_message)
      end

      # Close the WebSocket connection.
      def close(...)
        websocket.close(...) if websocket.alive?
      end

      # Invoke a method on the connection asynchronously through the pool of thread workers.
      def perform_work(receiver, method, *args)
        worker_pool.async_invoke(receiver, method, *args, connection: self)
      end

      def send_async(method, *arguments)
        worker_pool.async_invoke(self, method, *arguments)
      end

      # The request that initiated the WebSocket connection is available here. This gives access to the environment, cookies, etc.
      def request
        @request ||= begin
          environment = Rails.application.env_config.merge(env) if defined?(Rails.application) && Rails.application
          ActionDispatch::Request.new(environment || env)
        end
      end

      # Decodes WebSocket messages and dispatches them to subscribed channels.
      # WebSocket message transfer encoding is always JSON.
      def receive(websocket_message) # :nodoc:
        send_async :dispatch_websocket_message, websocket_message
      end

      def dispatch_websocket_message(websocket_message) # :nodoc:
        if websocket.alive?
          @connection.handle_incoming decode(websocket_message)
        else
          logger.error "Ignoring message processed after the WebSocket was closed: #{websocket_message.inspect})"
        end
      end

      def on_open # :nodoc:
        send_async :handle_open
      end

      def on_message(message) # :nodoc:
        message_buffer.append message
      end

      def on_error(message) # :nodoc:
        # log errors to make diagnosing socket errors easier
        logger.error "WebSocket error occurred: #{message}"
      end

      def on_close(reason, code) # :nodoc:
        send_async :handle_close
      end

      def inspect # :nodoc:
        "#<#{self.class.name}:#{'%#016x' % (object_id << 1)}>"
      end

      private
        attr_reader :websocket
        attr_reader :message_buffer

        def encode(cable_message)
          @coder.encode cable_message
        end

        def decode(websocket_message)
          @coder.decode websocket_message
        end

        def handle_open
          @protocol = websocket.protocol

          @connection.handle_open

          message_buffer.process!
          server.add_connection(@connection)
        end

        def handle_close
          logger.info finished_request_message

          server.remove_connection(@connection)
          @connection.handle_close
        end

        def respond_to_successful_request
          logger.info successful_request_message
          websocket.rack_response
        end

        def respond_to_invalid_request
          close if websocket.alive?

          logger.error invalid_request_message
          logger.info finished_request_message
          [ 404, { Rack::CONTENT_TYPE => "text/plain; charset=utf-8" }, [ "Page not found" ] ]
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
